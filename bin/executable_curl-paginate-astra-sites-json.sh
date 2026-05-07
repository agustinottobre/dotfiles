#!/bin/bash
# Get result of page 1 to count for paging calls
pageoffset=50
totalresults=$(curl -sSL -I -X GET https://websitedemos.net/wp-json/wp/v2/astra-sites | grep "x-wp-total:" | sed 's/^[^:]*: //')
# totalpages=$(curl -sSL -I -X GET https://websitedemos.net/wp-json/wp/v2/astra-sites | grep "x-wp-totalpages:" | sed 's/^[^:]*: //')

echo totalresults: $totalresults
# echo totalpages: $totalpages
calculated_totalpages=$(echo "if ( $totalresults%$pageoffset ) $totalresults/$pageoffset+1 else $totalresults/$pageoffset" |bc)
echo calculated_totalpages: $calculated_totalpages

# Take each page, get it and save as a separate file
for ((i=1;i<=calculated_totalpages;i++));
    do curl -s "https://websitedemos.net/wp-json/wp/v2/astra-sites?per_page="$pageoffset"&page="$i | jq . >| "/tmp/_content"$i".json";
       echo fetched page: $i
       sleep 0.5; # Add delay of 0.3s to not be kicked due to rate limitations
done;

# Merge your JSONs "et voilà!" as we say in French
cat /tmp/_content*.json | jq -s add >| /tmp/_out.json
