KEY=***REMOVED***

curl "http://developer.echonest.com/api/v4/catalog/list?api_key=$KEY&format=json"

curl \
-F "api_key=$KEY" \
-F "format=json" \
-F "type=song" \
-F "name=test" \
"http://developer.echonest.com/api/v4/catalog/create"

curl -X POST \
-F "api_key=$KEY" \
-F "data_type=json" \
-F "format=json" \
-F "id=CAMKRCC142884712C8" \
-F 'data=[{"item":{"item_id":"1","track_id":"spotify-WW:track:1zHlj4dQ8ZAtrayhuDDmkY"}}]' \
"http://developer.echonest.com/api/v4/catalog/update"

curl "http://developer.echonest.com/api/v4/catalog/status?api_key=$KEY&format=json&ticket=CAMKRCC142884712C85D2DD32B3C5147" | beautijson

curl "http://developer.echonest.com/api/v4/catalog/read?api_key=$KEY&format=json&id=CAMKRCC142884712C8&bucket=id:spotify-WW" | beautijson

curl "http://developer.echonest.com/api/v4/catalog/read?api_key=$KEY&format=json&id=CAHODPE1418D73A06D&bucket=genre&bucket=terms&bucket=artist_location" | beautijson



curl -X POST \
"http://developer.echonest.com/api/v4/catalog/update" \
-F "api_key=$KEY" \
-F "data_type=json" \
-F "format=json" \
-F "id=CAJVWVJ1418D266BB5" \
-F 'data=[{"item":{"item_id":"spotify-WW:track:7GmELLCacoDxgw74xfeUE4","artist_id":"spotify-WW:track:294vBlXfZYspeI29SXZaON"}}]'






