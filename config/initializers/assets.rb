# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Load Tabler and its bundled libraries through Sprockets.
Rails.application.config.assets.paths << Rails.root.join("node_modules", "@tabler", "core", "dist")
