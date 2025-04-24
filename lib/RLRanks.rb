require 'core'
require 'discordrb'
require 'json'
require 'rlranks'
require 'steam'

require_relative 'RLDB'
require_relative 'RLRoles'

class RLRanks
  def self.ranks(member, event)
    event.channel.send_message(
        "Now fetching ranks for: **#{member.display_name}**...")

    db_user = RLDB.user(member.id, member.server.id)
    ranks = fetch_ranks(db_user)
    unless ranks
      event.channel.send_message(
          "Couldn't fetch ranks for #{member.display_name}.")
      return RLRanks.new(db_user.id, db_user.account, db_user.platform)
    end

    RLDB.store_ranks(ranks)

    playlists = RLDB.server_playlists(member.server.id)
    if ranks.unranked?(playlists)
      event.channel.send_message(
          "#{member.display_name} isn't ranked in anything.")
      return ranks
    end

    best_rank = ranks.best(playlists)
    event.channel.send_embed { |embed|
      embed.title = "**#{member.display_name}**'s Ranks"
      embed.timestamp = Time.now
      embed.color = 0xff0000

      _, longest_rank = ranks.max_by { |_, rank| rank.playlist.length }
      playlist_length = longest_rank.playlist.length
      embed.description = <<~DESCRIPTION.strip
        ```fix
        #{ranks.map { |_, rank|
          "#{rank.playlist.rjust(playlist_length)}: #{RLUtils.rank_name(rank)}"
        }.join("\n")}
        ```
      DESCRIPTION

      embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(
          url: RLUtils.rank_url(best_rank))

      embed.footer = Discordrb::Webhooks::EmbedFooter.new(
          text: best_rank.playlist,
          icon_url: RLUtils.rank_url(best_rank))

      if db_user.platform == :steam
        player_summary = Steam::API.new.player_summary(db_user.account)
        embed.author = Discordrb::Webhooks::EmbedAuthor.new(
            name: player_summary[:personaname],
            url: player_summary[:profileurl],
            icon_url: player_summary[:avatarfull])
      end
    }

    return ranks
  end

  ##### PRIVATE #####

  class Error < RuntimeError; end
  private_constant :Error

  # Returns false if no ranks could be found
  def self.fetch_ranks(user)
    methods = {
      RLTracker: -> { rltracker(user) },
      RLDB: -> { RLDB.ranks(user.id, user.account, user.platform) }
    }
    methods.each_pair { |name, job|
      begin
        response = job.run
      rescue Error
        Discordrb::LOGGER.warn("#{name} failed for #{user}")
      end
      return response if response
    }
    return false
  end
  private_class_method :fetch_ranks

  RLT_PLATFORM_MAP = { steam: :steam, xbox: :xbl, ps: :psn, epic: :epic }.freeze
  private_constant :RLT_PLATFORM_MAP

  # rubocop:disable Lint/SymbolConversion
  RLT_RANK_MAP = {
    'Ranked Duel 1v1': :duel,
    'Ranked Doubles 2v2': :doubles,
    'Ranked Standard 3v3': :standard,
    'Hoops': :hoops,
    'Rumble': :rumble,
    'Dropshot': :dropshot,
    'Snowday': :snow_day,
    'Tournament Matches': :tournament
  }.freeze
  private_constant :RLT_RANK_MAP
  # rubocop:enable Lint/SymbolConversion

  def self.rltracker(user)
    base_url = 'https://api.tracker.gg/api/v2/rocket-league/standard/profile'
    response = get_response(<<~URI.chomp)
      #{base_url}/#{RLT_PLATFORM_MAP[user.platform]}/#{user.account}
    URI

    begin
      data = JSON.parse(response)['data']
      playlists = data['segments'].select { |segment|
        segment['type'] == 'playlist'
      }
      rank_list = playlists.to_h { |playlist|
        [
          playlist['metadata']['name'],
          {
            rank: playlist['stats']['tier']['value'],
            mmr: playlist['stats']['rating']['value']
          }
        ]
      }
    rescue StandardError
      raise Error
    end

    raise Error if rank_list.empty?

    ranks = {}
    rank_list.each { |playlist, rank_info|
      if rank_info[:rank].positive?
        rank_info[:rank] -= 1
        ranks[RLT_RANK_MAP.fetch(playlist.to_sym)] = rank_info.values
      end
    }

    return RLRanks.new(user.id, user.account, user.platform, **ranks)
  end
  private_class_method :rltracker

  # Helper for wrapping HTTP calls.  Throws Error on any failure.
  def self.get_response(url)
    begin
      # rubocop:disable Layout/LineLength
      response = `curl '#{url}' -X 'GET' -H 'Accept: application/json, text/plain, */*' -H 'Origin: https://rocketleague.tracker.network' -H 'Host: api.tracker.gg' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15' -H 'Accept-Language: en' -H 'Referer: https://rocketleague.tracker.network/' -H 'Connection: keep-alive'`
      # rubocop:enable Layout/LineLength
    rescue StandardError
      raise Error
    end
    return response
  end
  private_class_method :get_response
end
