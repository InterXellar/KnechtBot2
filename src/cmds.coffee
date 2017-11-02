main = require "./main.js"
funcs = require "./funcs.coffee"
aload = require "after-load"
main = require "./main.js"

# Getting bot instance from main script
bot = null
exports.setBot = (b) -> bot = b


###
<>      -> Argument
(<>)    -> optional argument
[]      -> variable option
###


# Just a test command for development purposes
exports.test = (msg, args) ->
    console.log msg.channel.type
    # funcs.xpchange msg.member, -8
    # RETURN ROLENAMES IN CONSOLE
    # console.log bot.guilds.find(-> return true).roles.map (m) -> return "#{m.name} - #{m.id}"

    # COLOR DEV ROLES LIKE GITHUB COLORS
    # clrs = JSON.parse require("fs").readFileSync('colors.json', 'utf8')
    # for c of clrs
    #     role = msg.member.guild.roles.find (r) -> r.name.toLowerCase() == c.toLowerCase()
    #     if typeof role != "undefined"
    #         bot.editRole msg.member.guild.id, role.id, {color: parseInt clrs[c].replace "#", "0x" }
    #         console.log "Updated role #{role.name} to Color: #{parseInt clrs[c].replace "#", "0x"}"


###
Help command: '!help'
Sends all command invokes in a private message.
###
exports.help = (msg, args) ->
    cmdlist = ""
    for invoke of main.commands
        cmdlist += ":white_small_square:  **`#{invoke}`**  -  #{main.commands[invoke][1]}\n"
    bot.getDMChannel(msg.author.id)
        .then (chan) ->
            main.sendEmbed chan,
                           """
                           Hey! :wave:

                           Currently, this bot is in early developent, so a lot of functions of the old Knecht Bot will be implemented later ;)

                           **Commands:**
                           #{cmdlist}
                           """


###
Say command: '!say <-e(:[color])> <message>'
Send a message, can be also an embeded message (with customizable color) with the bot.
###
exports.say = (msg, args) ->
    if !funcs.checkPerm msg.member, 2
        console.log "Not permitted"
        return
    if args.length > 0
        argstr = ""
        argstr += arg + " " for arg in args
        if argstr.toLowerCase().indexOf("-e") > -1 and argstr.toLowerCase().indexOf("-e") < 1
            color = main.color.gold
            if argstr.toLowerCase().indexOf("-e:") > -1
                clrstr = argstr.toLowerCase().split("-e:")[1].split(" ")[0]
                if clrstr of main.color
                    color = main.color[clrstr]
                argstr = argstr.split("-e:#{clrstr} ")[1]
            else
                argstr = argstr.split("-e ")[1]
            main.sendEmbed msg.channel, argstr, null, color
        else
            bot.createMessage msg.channel.id, argstr
    else
        colors = ""
        colors += "'#{c}', " for c of main.color
        main.sendEmbed msg.channel,
                       """
                       `!say <message>`  -  Send a normal message
                       `!say -e <message>`  -  Send an gold colored embed message
                       `!say -e:<color> <message>`  -  Send an colored embed message
                        *Available colors: #{colors.substring 0, colors.length - 2}*
                       """,
                       "USAGE:",
                       main.color.red
    bot.deleteMessage msg.channel.id, msg.id


###
Dev command: '!dev (<lang1>) (<lang2>) (<lang3>) ...'
Adding dev language roles to sender.
Roles will be get out of an online pastebin text file.
###
exports.dev = (msg, args) ->
    memb = msg.member
    chan = msg.channel
    guild = memb.guild
    available = aload.$(aload "https://pastebin.com/raw/7UE5euBg")('pre').text().split(", ")

    if args.length > 0
        entered = []
        added = failed = ""
        guildroles = guild.roles.map (r) -> return r
        for arg in args
            entered.push if "," in arg then arg.substring(0, arg.length - 1) else arg
        for rn in entered
            if rn in available
                for role in guildroles
                    if role.name.toLowerCase() == rn
                        bot.addGuildMemberRole guild.id, memb.id, role.id
                        added += "#{role.name}, "
                    else if role.name.toLowerCase() in entered
                        failed += "#{role.name} (failed), "
            else
                failed += "#{rn} (not available), "
        main.sendEmbed msg.channel,
                       """
                       Added roles:
                       ```
                       #{if added.length == 0 then "- none -" else added.substring 0, added.length - 2}
                       ```
                       Failed adding roles:
                       ```
                       #{if failed.length == 0 then "- none -" else failed.substring 0, failed.length - 2}
                       ```
                       """,
                       null,
                       main.color.gold
    else
        avstring = "" 
        avstring += "#{av}, " for av in available
        main.sendEmbed msg.channel,
                       """
                       `!dev lang1 lang2 lang3 ...`  -  Add lanuage roles

                       Available roles:
                       ```
                       #{avstring.substring 0, avstring.length - 2}
                       ```
                       """,
                       "USAGE:",
                       main.color.red


###
Invite command: '!invite (<botId>)'
Invite your bot as a userbot to the server.
In main's 'exports.inviteReceivers' map's members will receive a message with
the assmebled invite link, which they need to accept manually. Then, the botowner
will get a message and the bot and owner will be pushed in main's 'exports.botinvites'
list to prepare for bot acception procedure.
###
exports.invite = (msg, args) ->
    if args.length > 0
        bid = args[0]
        main.botInvites[args[0]] = msg.member
        for u in main.inviteReceivers
            bot.getDMChannel(u)
                .then (chan) ->
                    main.sendEmbed chan, "[Bot unvite from #{msg.author.username}](https://discordapp.com/oauth2/authorize?client_id=#{bid}&scope=bot)", "BOT INVTE", main.color.gold
    else
        main.sendEmbed msg.channel, "`!invite <botID>`\n*You can get your Bot ID from the [Discord Apps Panel](https://discordapp.com/developers/applications/me) from `Client ID`.*", "USAGE:", main.color.red


###
Prefix command: '!prefix (<botId>) (<prefix>)'
With no argument, the command will display all bots and their owners
with the registered prefix. All unregistered bots will be listed 
in a special list below.
Prefix can be set with entering botID and prefix as argument.
In dtabase will be checked before, if bot is registered as userbot,
if the prefix ist still given to another bot and if the sender is the
owner of the bot he will change prefix of.
###
exports.prefix = (msg, args) ->
    botid = ownerid = prefix = null
    chan = msg.channel
    sender = msg.member

    set = ->
        main.dbcon.query 'SELECT * FROM userbots WHERE botid = ?', [botid], (err, res) ->
            if err or res == null or res.length == 0
                main.sendEmbed chan, "Bot with the id `#{botid}` is not registered!", "Error", main.color.red
                return
            if res[0].ownerid != sender.id
                main.sendEmbed chan, "You can only set prefix of your own bots!", "Error", main.color.red
                return
            main.dbcon.query 'SELECT * FROM userbots WHERE prefix = ?', [prefix], (err, res) ->
                if err or res.length > 0
                    main.sendEmbed chan, "The preifix `#{prefix}` is still used!", "Error", main.color.red
                    return
                main.dbcon.query 'UPDATE userbots SET prefix = ? WHERE botid = ?', [prefix, botid], (err, res) ->
                    if err or res == null or res.length == 0
                        main.sendEmbed chan, "There occured an error setting the prefix.", "Error", main.color.red
                        return
                    main.sendEmbed chan, "Prefix successfully set to `#{prefix}`!", "Error", main.color.green

    list = ->
        out = unset = whitelisted = ""
        main.dbcon.query 'SELECT * FROM userbots', (err, res) ->
            if !err and row != null
                maxlen = 0
                for row in res
                    maxlen = if row.prefix.length > maxlen then row.prefix.length else maxlen
                btf = (inpt) ->
                    out = inpt
                    while out.length < maxlen
                        out += " "
                    return out
                for row in res
                    ubot = sender.guild.members.find (m) -> m.id == "#{row.botid}"
                    uowner = sender.guild.members.find (m) -> m.id == "#{row.ownerid}"            
                    if typeof ubot != "undefined" and typeof uowner != "undefined"
                        if row.prefix == "UNSET" and row.whitelisted == 0
                            unset += "#{ubot.username} *(#{uowner.username})*\n"
                        else if row.whitelisted == 0
                            out += "#{btf row.prefix}  -  #{ubot.username} (#{uowner.username})\n"
                        else if row.whitelisted == 1
                            whitelisted += "#{ubot.username} *(#{uowner.username})*\n"
                bot.createMessage chan.id, "**REGISTERED PREFIXES**\n\n```\n#{out}\n```\n\n\n**BOTS WITH UNSET PREFIX**\n\n#{unset}\n\n**WHITELISTED BOTS WITHOUT PREFIX**\n\n#{whitelisted}"


    if args.length < 2
        list()
    else
        if args[0] == "list"
            list()
            return
        botid = args[0]
        ownerid = sender.id
        prefix = args[1]
        set()
        

###
Info command: '!info'
Displays info text about bot.
###
exports.info = (msg, args) ->

    emb =
        embed:
            title: "KnechtBot V2 - Info"
            color: main.color.gold
            description: """
                         Discord bot created for managing zekro's Dev Guild.
                         This bot is a rework of [KnechtBot](https://github.com/zekroTJA/regiusBot) project in NodeJS.

                         © 2017 Ringo Hoffmann (zekro Development)
                         """
            thumbnail:
                url: bot.user.avatarURL
            fields: [ 
                {
                    name: "Current Version"
                    value: "v.#{main.version}"
                    inline: false,
                }
                {
                    name: "GitHub"
                    value: "**[KnechtBot V2 GitHub Repository](https://github.com/zekroTJA/KnechtBot2)**"
                    inline: false
                }
                {
                    name: "Contributors"
                    value: """
                           :white_small_square:   [zekro](https://github.com/zekrotja)
                           """
                    inline: false
                }
                {
                    name: "Used 3rd Party Packages"
                    value: """
                           :white_small_square:   [Eris](https://github.com/abalabahaha/eris)
                           :white_small_square:   [CoffeeScript](https://github.com/jashkenas/coffeescript)
                           :white_small_square:   [After-Load](https://www.npmjs.com/package/after-load)
                           :white_small_square:   [MySql](https://github.com/mysqljs/mysql)
                           """
                    inline: false,
                } ]
    bot.createMessage msg.channel.id, emb


###
Github command: '!github list'
                '!github add <github profile name>'
                '!github remove'
Command to link github profiles to discord accounts in database.
Thats essential for user command to display github account there.
###
exports.github = (msg, args) ->
    sender = msg.member
    chan = msg.channel

    add = (profile) ->
        main.dbcon.query 'SELECT * FROM github WHERE uid = ?', [sender.id], (err, res) ->
            if res == null or res.length == 0
                main.sendEmbed chan, "Testing profile existence..."
                    .then (m) ->
                        if aload.$(aload "https://github.com/#{profile}")('title').text().indexOf("Page not found") > -1
                            bot.editMessage chan.id, m.id, {embed: {description: "Github profile `#{profile}` does not exist!", color: main.color.red}}
                        else
                            main.dbcon.query 'INSERT INTO github (uid, gitid) VALUES (?, ?)', [sender.id, profile], (err, res) ->
                                if !err
                                    bot.editMessage chan.id, m.id, {embed: {description: "Linked profile `#{profile}` to discord user #{sender.mention}.", color: main.color.green}}
            else if res.length > 0
                main.sendEmbed chan, "Testing profile existence..."
                    .then (m) ->
                        if aload.$(aload "https://github.com/#{profile}")('title').text().indexOf("Page not found") > -1
                            bot.editMessage chan.id, m.id, {embed: {description: "Github profile `#{profile}` does not exist!", color: main.color.red}}
                        else
                            main.dbcon.query 'UPDATE github SET gitid = ? WHERE uid = ?', [profile, sender.id], (err, res) ->
                                if !err
                                    bot.editMessage chan.id, m.id, {embed: {description: "Linked profile `#{profile}` to discord user #{sender.mention}.", color: main.color.green}}

    remove = ->
        main.dbcon.query 'SELECT * FROM github WHERE uid = ?', [sender.id], (err, res) ->
            if res == null or res.length == 0
                main.sendEmbed chan, "You don't have a github profile linked to remove!", null, main.color.red
            else
                main.dbcon.query 'DELETE FROM github WHERE uid = ?', [sender.id], (err, res) ->
                    if !err
                        main.sendEmbed chan, "Successfully unlinked github profile!", null, main.color.green

    list = ->
        main.dbcon.query 'SELECT * FROM github', (err, res) ->
            if !err and res.length > 0
                out = ""
                for row in res
                    user = sender.guild.members.find (m) -> m.id == "#{row.uid}"
                    git = "https://github.com/#{row.gitid}"
                    if typeof user != "undefined"
                        out += ":white_small_square:  [#{user.username}](#{git})\n"
                main.sendEmbed chan, out, "Linked GitHub profiles"

    if args.length > 1
        if args[0] == "add" or args[0] == "link"
            profile = ""
            if args[1].startsWith("https://github.com/")
                profile = args[1].replace("https://github.com/", "")
            else if args[1].startsWith("http://github.com/")
                profile = args[1].replace("http://github.com/", "")
            else if args[1].startsWith("www.github.com/")
                profile = args[1].replace("www.github.com/", "")
            else if args[1].startsWith("github.com/")
                profile = args[1].replace("github.com/", "")
            else
                profile = args[1]
            add profile
    else if args.length > 0
        if args[0] == "remove" or args[0] == "unlink"
            remove()
        else if args[0] == "list"
            list()
    else
        main.sendEmbed chan, """
                             `!git list`  -  List all linked GitHub accounts
                             `!git add <Profile name or URL>`  -  Link GitHub profile to your discord account
                             `!git remove`  -  Unlink GitHub profile from your discord account
                             """, "USAGE:", main.color.red


###
User profile command: '!user <mention/ID/name>'
Get general information about user and his userbots
and registered github profile, when existent.
###
exports.user = (msg, args) ->
    user = null
    if args.length > 0
        if msg.mentions.length > 0
            user = msg.member.guild.members.find (m) -> m.id == msg.mentions[0].id
        else
            user = msg.member.guild.members.find (m) -> m.id == args[0]
            if typeof user == "undefined"
                user = msg.member.guild.members.find (m) -> m.username.toLowerCase().indexOf(args[0].toLowerCase()) > -1
                if typeof user == "undefined"
                    main.sendEmbed msg.channel, "User `#{args[0]}` could not be found!", "Error", main.color.red
                    return

        getRoles = ->
            out = ""
            for r in user.roles
                out += ", " + msg.member.guild.roles.find((role) -> role.id == r).name
            return out.substring 2

        getColor = ->
            switch funcs.getPerm user
                when 0 then return 0xf9f9f9
                when 1 then return 0x0ec4ed
                when 2 then return 0x45ed0e
                when 3 then return 0xed0e0e

        botout = ""
        main.dbcon.query 'SELECT * FROM userbots WHERE ownerid = ?', [user.id], (err, res) ->
            if err or res.length == 0
                botout = "No userbots"
            else
                for row in res
                    ubot = msg.member.guild.members.find (b) -> b.id == row.botid
                    if typeof ubot != "undefined"
                        botout += ", " + ubot.mention
                botout = botout.substring 2

            github = ""
            main.dbcon.query 'SELECT * FROM github WHERE uid = ?', [user.id], (err, res) ->
                if err or res.length == 0
                    github = "No GitHub profile linked"
                else
                    github = "[#{res[0].gitid}](https://github.com/#{res[0].gitid})"

                main.dbcon.query 'SELECT * FROM reports WHERE victim = ?', [user.id], (err, res) ->
                    reports = res.length

                    main.dbcon.query 'SELECT * FROM xp WHERE uid = ?', [user.id], (err, res) ->
                        if err or res.length == 0
                            xpval = 0
                        else if !err
                            xpval = res[0].xp
                        xpvals = funcs.xpgetlvl(xpval)
                        xpd = """
                              **LVL #{xpvals[0]}**
                              #{xpvals[1]} / #{xpvals[2]} *(#{xpvals[3]} %)*
                              """

                        emb =
                            embed:
                                title: "#{user.username} - User Profile"
                                thumbnail:
                                    url: user.avatarURL
                                color: getColor user
                                fields: [
                                    {
                                        name: "Username"
                                        value: "#{user.username}##{user.discriminator}"
                                        inline: false
                                    }
                                    {
                                        name: "Nickname"
                                        value: if typeof user.nick == "undefined" then "No nick set" else user.nick
                                        inline: false
                                    }
                                    {
                                        name: "ID"
                                        value: user.id
                                        inline: false
                                    }
                                    {
                                        name: "Current Game"
                                        value: "#{if user.game == null then 'No game played' else user.game.name}"
                                        inline: false
                                    }
                                    {
                                        name: "Current Status"
                                        value: user.status
                                        inline: false
                                    }
                                    {
                                        name: "Joined Guild at"
                                        value: user.joinedAt
                                        inline: false
                                    }
                                    {
                                        name: "Roles on this Guild"
                                        value: getRoles()
                                        inline: false
                                    }
                                    {
                                        name: "GitHub"
                                        value: "**#{github}**"
                                        inline: false
                                    }
                                    {
                                        name: "Level"
                                        value: xpd
                                        inline: false
                                    }
                                    {
                                        name: "Reports"
                                        value: "#{if reports == 0 then "This user has a white west!" else "**#{reports} reports** in past."}"
                                        inline: false
                                    }
                                    {
                                        name: "User Bots"
                                        value: botout
                                        inline: false
                                    }
                                ]
                        bot.createMessage msg.channel.id, emb


###
ID command: '!id <search query>'
Getting IDs of guild elements by search query.
###
exports.getid = (msg, args) ->
    if args.length < 1
        main.sendEmbed msg.channel, "`!id <search query>`", "USAGE:", main.color.red
        return
    
    query = ""
    query += " " + arg for arg in args
    query = query.substr(1).toLowerCase()
    guild = msg.member.guild
    roles = membs = chans = ""

    roles += "#{r.name}  -  `#{r.id}`\n" for r in guild.roles.filter (role) -> role.name.toLowerCase().indexOf(query) > -1
    chans += "#{c.name}  -  `#{c.id}`\n" for c in guild.channels.filter (chan) -> chan.name.toLowerCase().indexOf(query) > -1
    membs += "#{m.username}  -  `#{m.id}`\n" for m in guild.members.filter (memb) -> memb.username.toLowerCase().indexOf(query) > -1

    emb =
        embed:
            title: "Results for '#{query}'"
            fields: [
                {
                    name: "Roles"
                    value: "#{if roles.length == 0 then "Nothing found." else roles}"
                    inline: false
                }
                {
                    name: "Channels"
                    value: "#{if chans.length == 0 then "Nothing found." else chans}"
                    inline: false
                }
                {
                    name: "Members"
                    value: "#{if membs.length == 0 then "Nothing found." else membs}"
                    inline: false
                }
            ]

    bot.createMessage msg.channel.id, emb

###
Report command: '!report <@mention/ID> <reason>'
                '!report info <@mention/ID>'
Report a user for rule-violating behaviour.
Reports will be saved in the DB and counted.
You can also get info about report state with 'info'
argument or in the profile page of the user ('user' command)
###
exports.report = (msg, args) ->
    chan = msg.channel
    sender = msg.member
    victim = null
    reason = ""

    if args.length < 2
        main.sendEmbed chan, """
                             `!rep <@mention/ID> <reason>`  -  Report a member
                             `!rep info <@mention/ID>`  -  Get all reports of a member
                             """, "USAGE:", main.color.red
        return

    if args[0] == "info"
        if msg.mentions.length > 0
            victim = sender.guild.members.find (m) -> m.id == msg.mentions[0].id
        else    
            victim = sender.guild.members.find (m) -> m.id == args[1]

        if typeof victim == "undefined"
            main.sendEmbed chan, "Please enter a valid member!", "USAGE:", main.color.red
            return

        main.dbcon.query 'SELECT * FROM reports WHERE victim = ?', [victim.id], (err, res) ->
            if !err
                if res.length == 0
                    main.sendEmbed chan, "User #{victim.mention} has a white west! :thumbsup:", "Reports", main.color.green
                else
                    reps = ""
                    for row in res
                        reporter = sender.guild.members.find (m) -> m.id == row.reporter
                        reps += "`[#{row.date}]` - by #{if typeof reporter == "undefined" then "Not more on guild" else reporter.mention} - Reason: #{row.reason}\n"
                    main.sendEmbed chan, """
                                         User #{victim.mention} got reported **#{res.length} times**.

                                         **Reports:**
                                         #{reps}
                                         """, "Reports", main.color.orange
    else
        if !funcs.checkPerm msg.member, 2
            return

        if msg.mentions.length > 0
            victim = sender.guild.members.find (m) -> m.id == msg.mentions[0].id
        else    
            victim = sender.guild.members.find (m) -> m.id == args[0]

        if typeof victim == "undefined"
            main.sendEmbed chan, "Please enter a valid member!", "USAGE:", main.color.red
            return

        reason += " " + arg for arg in args[1..]
        main.dbcon.query 'INSERT INTO reports (victim, reporter, date, reason) VALUES (?, ?, ?, ?)', [victim.id, sender.id, main.getTime(), reason.substr 1], (err, res) ->
            if !err
                main.dbcon.query 'SELECT * FROM reports WHERE victim = ?', [victim.id], (err, res) ->
                    main.sendEmbed chan, "Reported #{victim.mention} by #{sender.mention} for reason ```\n#{reason}\n```\nUser got reported **#{res.length} times** now.", "Report", main.color.orange
                    kerbholz = bot.getChannel "342627519825969172"
                    main.sendEmbed kerbholz, "Reported #{victim.mention} by #{sender.mention} for reason ```\n#{reason}\n```\nUser got reported **#{res.length} times** now.", "Report", main.color.orange
                    if res.length == 2
                        bot.getDMChannel(victim.id)
                            .then (chan) -> main.sendEmbed chan, """
                                                                 :warning:   **WARNING**

                                                                 You got reported **2 times** now on this guild by a staff member.
                                                                 If you will show any rule-violating behaviour again, **you will be kicked or banned!**

                                                                 Remember: Reports will **never** expire and will be always visible in your profile, also
                                                                 all reports of you can be displayed every user with the `!report info` command.
                                                                 Reports will not disappear if you quit and rejoin the guild!
                                                                 """, null, main.color.red

###
XP command: '!xp'
            '!xp <@mention/ID/name>'
Get the current top 20 list of xp on the guild or
get the specific xp ammount and need-xp for next
level of a specified user.
###
exports.xp = (msg, args) ->
    user = null
    if args.length > 0
        if msg.mentions.length > 0
            user = msg.member.guild.members.find (m) -> m.id == msg.mentions[0].id
        else
            user = msg.member.guild.members.find (m) -> m.id == args[0]
            if typeof user == "undefined"
                user = msg.member.guild.members.find (m) -> m.username.toLowerCase().indexOf(args[0].toLowerCase()) > -1
                if typeof user == "undefined"
                    main.sendEmbed msg.channel, "User `#{args[0]}` could not be found!", "Error", main.color.red
                    return
        main.dbcon.query 'SELECT * FROM xp WHERE uid = ?', [user.id], (err, res) ->
            if !err and res.length > 0
                lvldata = funcs.xpgetlvl res[0].xp
                main.sendEmbed msg.channel,
                               """
                               **LVL #{lvldata[0]}** *(#{res[0].xp} XP)*
                               ```
                               #{lvldata[1]} / #{lvldata[2]} (#{lvldata[3]} %)
                               [#{"####################".substring(0, parseInt(20 * lvldata[3] / 100))}#{"                    ".substring(0, 20 - parseInt(20 * lvldata[3] / 100))}]
                               ```
                               """, "LVL OF USER #{user.username}", main.color.gold
    else
        toplist = ""
        main.dbcon.query 'SELECT * FROM `xp` ORDER BY `xp`.`xp` DESC', (err, res) ->
            if !err and res.length > 0
                ind = 0
                numbs = names = xps = ""
                btf = (inpt, should) -> 
                    while should > "#{inpt}".length
                        inpt = "0" + inpt
                    return inpt
                maxxplen = "#{res[0].xp}".length
                for row in res
                    if ind < 20
                        user = msg.member.guild.members.find (m) -> m.id == row.uid
                        if !user.bot
                            toplist += "**#{btf(++ind, 2)}**  -  `LVL #{btf(funcs.xpgetlvl(row.xp)[0], 2)} (#{btf(row.xp, maxxplen)} XP)`  -  #{if typeof user == "undefined" then "Not on server" else user.username}\n"
                emb =
                    embed:
                        title: "GUILD XP TOP 20 LIST"
                        color: main.color.gold
                        description: toplist
                bot.createMessage msg.channel.id, emb


###
Command Log command: '!cmdlog (<@mention/ID/name>)'
Displays last send commands of the bot with username, command + arguments,
timestamp and channel name.
###
exports.cmdlog = (msg, args) ->
    user = null
    if args.length > 0
        if msg.mentions.length > 0
            user = msg.member.guild.members.find (m) -> m.id == msg.mentions[0].id
        else
            user = msg.member.guild.members.find (m) -> m.id == args[0]
            if typeof user == "undefined"
                user = msg.member.guild.members.find (m) -> m.username.toLowerCase().indexOf(args[0].toLowerCase()) > -1
                if typeof user == "undefined"
                    main.sendEmbed msg.channel, "User `#{args[0]}` could not be found!", "Error", main.color.red
                    return
    outtext = temptext = "**CMD LIST**\n\n"
    main.dbcon.query 'SELECT * FROM cmdlog', (err, res) ->
        if !err and res.length > 0
            for row in res
                if typeof user == "undefined" or user.id == row.uid
                    temptext += "#{row.uname} - `#{row.content}` in #{row.channame} @ #{row.timestamp}\n"
                    if temptext.length > 2000
                        bot.createMessage msg.channel.id, outtext
                        return
                    else
                        outtext = temptext
            bot.createMessage msg.channel.id, if outtext == "**CMD LIST**\n\n" then "<no commands executed>" else outtext


###
WhoIs command: '!whois <ID>'
Getting the member/bot from an ID.
###
exports.whois = (msg, args) ->
    if args.length > 0
        user = msg.member.guild.members.find (m) -> m.id == args[0]
        if typeof user == "undefined"
            main.sendEmbed msg.channel, "No member found with the ID `#{args[0]}`.", null, main.color.red
        else
            main.sendEmbed msg.channel, """
                                        Found #{if user.bot then "bot" else "member"} #{user.mention} (#{user.username}#{user.discriminator})
                                        """, null, main.color.gold
    else
        main.sendEmbed msg.channel, "`!whois <ID>`", "USAGE:", main.color.red