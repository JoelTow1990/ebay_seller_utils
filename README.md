## Overview
ebay_seller_utils is a Ruby command-line tool designed to help eBay sellers efficiently manage and archive their listings. The utility retrieves seller listings from the eBay API, saves listing metadata, and downloads associated images in a structured local directory.
Features

Retrieve all seller listings within a specific time period
Save listing metadata as text files
Download and organize listing images
Configurable dry-run mode for safe testing

## Prerequisites

Ruby 3.x (3.3.5 preferred)
Bundler
eBay Developer Account
eBay API Credentials

## Installation

Clone the repository
Run `bundle install`
Create a .env file with your eBay API credentials:
USER_ID='your_user_id'
AUTH_TOKEN='your_auth_token'

## Usage
From the project root, run:
  `ruby bin/ebay_seller_utils.rb [--dry_run={true|false}]`

## Options

`--dry_run:`

`true` (default): Simulates the process without downloading files
`false`: Actually downloads listings and images

## Output Structure
Listings are saved in the following directory structure:

$HOME/EbayListings/
└── Category/
    └── listing_title/
        ├── metadata.txt
        ├── listing_title0.png
        ...
        └── listing_titleN.png

metadata.txt: Contains listing details
Images are saved in snake_case format derived from listing titles