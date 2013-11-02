KEY=***REMOVED***

curl \
-F "api_key=$KEY" \
-F "format=json" \
-F "type=song" \
-F "name=test" \
"http://developer.echonest.com/api/v4/catalog/create"


curl -X POST \
"http://developer.echonest.com/api/v4/catalog/update" \
-F "api_key=$KEY" \
-F "data_type=json" \
-F "format=json" \
-F "id=CAJVWVJ1418D266BB5" \
-F 'data=[{"item":{"item_id":"spotify-WW:track:7GmELLCacoDxgw74xfeUE4","artist_id":"spotify-WW:track:294vBlXfZYspeI29SXZaON"}}]'


curl \
"http://developer.echonest.com/api/v4/catalog/read?api_key=$KEY&format=json&id=CAJVWVJ1418D266BB5&bucket=id:spotify-WW"




