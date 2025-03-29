#!/bin/sh

API_URL=${API_URL:-http://localhost:3000}

sed -i "s|window.env = {|window.env = {\n\tAPI_URL: \"$API_URL\",\n|g" /usr/share/nginx/html/config.js
