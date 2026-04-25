require "dotenv"
Dotenv.load(Rails.root.join(".env")) if Rails.root.join(".env").exist?
