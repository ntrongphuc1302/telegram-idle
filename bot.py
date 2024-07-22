import configparser
from pyrogram import Client, filters
import time
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
    
    # Keep the account online by sending a message every 5 minutes
    while True:
        try:
            await client.send_message("me", "I am still here!")
            await asyncio.sleep(300)  # Sleep for 5 minutes
        except Exception as e:
            print(f"An error occurred: {e}")

if __name__ == '__main__':
    app.run()
