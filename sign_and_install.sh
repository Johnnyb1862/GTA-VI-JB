set -e

zsign -k ./.sign/pkey.p12 -p 1234 -m ./.sign/development.cer -b $1 -m ./.sign/profile.mobileprovision -o ./.sign/GTAVIJB.signed.ipa ./Application/GTAVIJB.ipa
ideviceinstaller install ./.sign/GTAVIJB.signed.ipa
