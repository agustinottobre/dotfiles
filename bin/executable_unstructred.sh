#!/bin/bash

# Check if a filename is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

# Get the input filename
input_file="$1"

# Check if the file exists
if [ ! -f "$input_file" ]; then
    echo "File not found: $input_file"
    exit 1
fi

# Get the directory of the input file
input_dir=$(dirname "$input_file")

# Get the base name of the file without extension
base_name=$(basename "$input_file" .pdf)

# Construct the output filename in the same directory
output_file="${input_dir}/${base_name}.json"

# Execute the curl command
curl -s -X 'POST' \
    'https://unstructured.0770127.xyz/general/v0/general' \
    -H 'accept: application/json' \
    -H 'Content-Type: multipart/form-data' \
    -F "files=@${input_file}" \
    -F 'strategy=hi_res' > "$output_file"

# Inform the user of the output
echo "Response saved to: $output_file"

