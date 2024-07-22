import configparser
from pyrogram import Client, filters
import asyncio

# Load configuration
config = configparser.ConfigParser()
config.read("config.ini")

api_id = config.get("pyrogram", "api_id")
api_hash = config.get("pyrogram", "api_hash")

# Create a Pyrogram Client
app = Client("my_account", api_id=api_id, api_hash=api_hash)

@app.on_message(filters.text & filters.private)
async def handle_message(client, message):
    # Respond with "pong" if the message is "ping"
    if message.text.lower() == "ping":
        await message.reply_text("Pong")

if __name__ == '__main__':
    # Start the client
    app.run()
