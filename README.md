# OCI capacity-reservation CLI helper

This script creates one Compute Capacity Reservation with multiple capacity
configurations. A configuration specifies an instance shape, its flexible-shape
OCPU/memory values (when applicable), and the number of instances to reserve.

## Configure the script

Before running it, edit the variable block near the top of
`create_capacity_reservation.sh`:

```bash
COMPARTMENT_ID="ocid1.compartment.oc1..your-compartment-ocid"
AVAILABILITY_DOMAIN="availability-domain-name"
DISPLAY_NAME="capacity-reservation-name"
CONFIGS_FILE="$script_dir/reservation-configs.example.json"
PROFILE="DEFAULT"
REGION=""
DEFAULT_RESERVATION=false
CAPACITY_RESERVATION_ID=""
```

Set `COMPARTMENT_ID`, `AVAILABILITY_DOMAIN`, and `DISPLAY_NAME` to values for
your tenancy. Update `CONFIGS_FILE` if you copy or rename the JSON file, and
set `PROFILE` to the OCI CLI profile that has permission to manage capacity
reservations. Leave `REGION` blank to use the default region configured for
`PROFILE` in `~/.oci/config`; otherwise, set it to an OCI region identifier
such as `us-phoenix-1`. Set `DEFAULT_RESERVATION=true` only when you intentionally want
this to be the tenancy's default reservation for that availability domain. A
default capacity reservation must be created in the **root compartment**:
when `DEFAULT_RESERVATION=true`, set `COMPARTMENT_ID` to the tenancy OCID
(`ocid1.tenancy...`), not to a child-compartment OCID. OCI permits only one
default capacity reservation per availability domain.
Set `CAPACITY_RESERVATION_ID` to update an existing reservation. If it is blank
or OCI cannot find that OCID, the script creates a new reservation instead.

When updating, `CONFIGS_FILE` becomes the complete desired set of capacity
configurations. Existing configurations omitted from that JSON file are
deleted by OCI. The script waits for the update work request to reach
`SUCCEEDED`.

After editing those values, run the script with no arguments:

```zsh
chmod +x create_capacity_reservation.sh
./create_capacity_reservation.sh
```

## Override values on the command line

You can instead leave the defaults blank and provide values at runtime. Command
line values override values set in the script:

```zsh
chmod +x create_capacity_reservation.sh
./create_capacity_reservation.sh \
  --compartment-id ocid1.compartment.oc1..example \
  --availability-domain 'kIdk:US-ASHBURN-AD-1' \
  --display-name k8s-capacity-reservation \
  --configs reservation-configs.example.json \
  --profile DEFAULT \
  --region us-phoenix-1 \
  --capacity-reservation-id <existing-capacity-reservation-ocid>
```

The example deliberately contains two `VM.Standard.E5.Flex` configurations
with the same OCPU count but different memory amounts. Adjust the requested
shape, OCPUs, memory, and `reservedCount` to values valid and available in the
target availability domain.

To restrict a configuration to a fault domain, add `"faultDomain":
"FAULT-DOMAIN-1"` to that configuration. Omit it to allow OCI to place an
instance in any fault domain in the reservation's availability domain.
