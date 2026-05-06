# Replace <username>, <password>, and <proxmox_host> with your details
PROXMOX_HOST="http://tower.local:8006"
USERNAME="root"
PASSWORD="11onceONCE"

# Get the CSRF token
CSRF_TOKEN=$(curl -s -k -d "username=$USERNAME&password=$PASSWORD" "$PROXMOX_HOST/api2/json/access/ticket" | jq -r '.data.CSRFPreventionToken')
echo $CSRF_TOKEN

# Get the list of VMs and Containers
curl -s -k -H "Authorization: PVEAPIToken=$USERNAME!tokenid:$CSRF_TOKEN" "$PROXMOX_HOST/api2/json/nodes/<node>/qemu" | jq '.data[] | {vmid: .vmid, ip: .ip}'
curl -s -k -H "Authorization: PVEAPIToken=$USERNAME!tokenid:$CSRF_TOKEN" "$PROXMOX_HOST/api2/json/nodes/<node>/lxc" | jq '.data[] | {ctid: .vmid, ip: .ip}'

