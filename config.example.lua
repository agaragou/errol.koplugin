return {
    telegram = {
        token = "123:ABC", -- bot token
        chat_id = "11111" -- your chat_id
    },
    discord = {
        webhook_url = "https://discord.com/api/webhooks/123/ABC" -- webhook from discord channel
    }
}

--[[
    SETUP GUIDE:

    TELEGRAM:
    1. Create a bot via @BotFather to get your 'token'.
    2. Get your 'chat_id' via @userinfobot (and press START in your bot!).

    DISCORD:
    1. Server Settings -> Integrations -> Webhooks -> New Webhook.
    2. Copy Webhook URL.
]]