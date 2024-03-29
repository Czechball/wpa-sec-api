# wpa-sec-api

Collection of bash scripts that work with [dwpa](https://github.com/RealEnder/dwpa) and [Wigle.net](https://wigle.net/)

# Dependencies
There are three dependencies:

* jq
* curl
* hcxpcapngtool (from [hcxtools](https://github.com/ZerBea/hcxtools))

# get-pot.sh
This script simply downloads your wpa-sec potfile. Nothing special.  
To use this and other wpa-sec related scripts, you need to run the `setup.sh` script, which will create a `config.txt` file. Alternatively you can copy the example config file and fill in the variables.

# sort-pot.sh
This script uses get-pot.sh to download your potfile, removes STA mac addresses, sorts all records by AP mac address and removes duplicates. On the first run, this script will simply generate a file named `current.potfile`. When you run it again, it will compare the currently downloaded potfile with the old `current.potfile` file. It will generate a file named `newsites.txt`, which will contain new cracked sites. It will also rename the old `current.potfile` to `old.potfile` and move the previous `old.potfile` to a folder named `archive`.

# upload-pcapng.sh
This script is used to upload capture files to wpa-sec.  
Usage:
```sh
./upload-pcapng.sh <filename(s)>
```
for a single file or multiple files (it's also possible to use wildcards, like 2020-12-\*), or
```sh
./upload-pcapng.sh -d <directory>
```
for uploading all files matching `*.pcapng*` in the given directory.  
You can also invoke a Zenity "GUI" by using the -g parameter:
```sh
./upload-pcapng.sh -g ...
```
It will also check if GPS data are present in .pcapng files that are being uploaded to wpa-sec, converts the GPS data to a [Wigle.net compatible CSV format](https://api.wigle.net/csvFormat.html) and uploads them to Wigle.net using the provided credentials. This is enabled by default and can be disabled in config.txt

# wigle-pos.sh
This script requires you to also fill out Wigle API credentials in `config.txt` (using the `setup.sh` script).  
wigle-pos.sh is used to geolocate cracked networks using Wigle.net. It will output a file formatted as following:  
```
lat;long;bssid;essid;psk
```
Please note that this script can potentionally break if essid or psk contains unsafe characters.  
Usage:
```sh
./wigle-pos.sh newsites.txt
```
this will output a file named current-date.txt  
As input, this script can only process potfiles outputted by `sort-pot.sh` (such as *current.potfile*, *old.potfile* and *newsites.txt*), **not** unformatted potfiles straight from wpa-sec.
