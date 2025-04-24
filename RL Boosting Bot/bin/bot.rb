require 'discordrb'
require 'jubibot'

require_relative '../lib/RLDB'
require_relative '../lib/RLBot'

Discordrb::LOGGER.streams = [$stdout, File.open('log', 'w')]

jubi = JubiBot.new(
    token: ENV['MTM2NTAyMTA4MDI4ODM2MjUzNw.GdxNKf.tDJ3It_hixNhg2kTU4astWomjQDtPiPySKBg7g'],
    command_bot: RLBot.instance,
    prefix: proc { |event| return RLDB.server_prefix(event&.server&.id) },
    doc_file: File.expand_path('../documentation/commands.yaml', __dir__),
    homepage: 'https://jubishop.com/Tusk/',
    support_channel: 'https://discord.gg/2YSmnyX',
    permissions: 470207553,
    error_message: 'Something went wrong.  Would you file an issue at ' \
                   'https://github.com/jubishop/Tusk/issues or join ' \
                   'https://discord.gg/2YSmnyX and tell `jubi` about it?')

#######################################
# MANAGEMENT
#######################################
jubi.command(:user_info, num_args: (0..1)) { |event, name|
  return jubi.member(event, name), event.server
}

jubi.command(
    :admin_register,
    num_args: (3..4),
    owners: 'tusk_admin') { |event, name, account_id, platform, region|
  platform.downcase!
  platform = 'ps' if platform.start_with?('ps')
  region&.upcase!
  platform = platform.to_sym
  RLBot.validate_platform(platform)
  RLBot.validate_region(region) if region

  return jubi.member(event, name), account_id, platform, region, event
}

jubi.command(:admin_unregister,
             num_args: 1,
             owners: 'tusk_admin') { |event, name|
  return jubi.member(event, name)
}

jubi.command(:playing,
             num_args: 1,
             whitelist: JubiBot::JUBI) { |event, game|
  return event.bot, game
}

jubi.command(:listening,
             num_args: 1,
             whitelist: JubiBot::JUBI) { |event, song|
  return event.bot, song
}

jubi.command(:watching,
             num_args: (1..),
             whitelist: JubiBot::JUBI) { |event, show|
  return event.bot, show
}

jubi.command(:playlists,
             num_args: (0..1),
             owners: 'tusk_admin') { |event, playlists = ''|
  return event.server, playlists.split('|')
}

jubi.command(:clear_playlists, owners: 'tusk_admin') { |event|
  return event.server
}

jubi.command(:update_all_roles, owners: 'tusk_admin') { |event|
  return event
}

jubi.command(:command_prefix) { |event|
  return event.server
}

jubi.command(:set_command_prefix,
             num_args: 1,
             owners: 'tusk_admin') { |event, prefix|
  return event.server, prefix
}

jubi.command(:enable_region_roles,
             aliases: [:enable_regional_roles],
             owners: 'tusk_admin') { |event|
  return event.server
}

jubi.command(:disable_region_roles,
             aliases: [:disable_regional_roles],
             owners: 'tusk_admin') { |event|
  return event.server
}

jubi.command(:enable_platform_roles, owners: 'tusk_admin') { |event|
  return event.server
}

jubi.command(:disable_platform_roles, owners: 'tusk_admin') { |event|
  return event.server
}

jubi.command(:uptime)

#######################################
# USER REGISTRATION MANAGEMENT
#######################################
jubi.command(:register,
             aliases: %i[add signup],
             num_args: (2..3)) { |event, account_id, platform, region|
  platform.downcase!
  platform = 'ps' if platform.start_with?('ps')
  region&.upcase!
  platform = platform.to_sym
  RLBot.validate_platform(platform)
  RLBot.validate_region(region) if region

  return event.author, account_id, platform, region, event
}

jubi.command(:unregister, aliases: %i[remove delete]) { |event|
  return event.author
}

#######################################
# RANK INFORMATION
#######################################
jubi.command(:ranks, aliases: [:rank], num_args: (0..1)) { |event, name|
  return jubi.member(event, name), event
}

#####################################
# STATS
#####################################
jubi.command(:series, num_args: (0..6)) { |event, *names|
  return jubi, event.author, jubi.members(event, names), event.channel
}

jubi.command(:alltime, num_args: (0..6)) { |event, *names|
  return jubi, event.author, jubi.members(event, names), event.channel
}

#######################################
# SIMPLE LINKS
#######################################
jubi.command(:invite) { return jubi }
jubi.command(:support)
jubi.command(:twitch)

jubi.command(:ballchasing, aliases: [:bc], num_args: (0..1)) { |event, name|
  return jubi.member(event, name)
}

jubi.command(:steam, num_args: (0..1)) { |event, name|
  return jubi.member(event, name)
}

jubi.command(:tracker, aliases: [:rltracker], num_args: (0..1)) { |event, name|
  return jubi.member(event, name)
}

##### LETS GO #####
jubi.run(async: true)
jubi.bot.join
