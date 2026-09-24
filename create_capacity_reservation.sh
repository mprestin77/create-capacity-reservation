#!/usr/bin/env bash
# Create an OCI Compute Capacity Reservation with one or more configurations.
#
# Example:
#   ./create_capacity_reservation.sh \
#     --compartment-id ocid1.compartment.oc1..example \
#     --availability-domain "kIdk:US-ASHBURN-AD-1" \
#     --display-name "k8s-reserved-capacity" \
#     --configs ./reservation-configs.json

set -euo pipefail

# Edit these defaults before running the script. Command-line options, when
# supplied, override them.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPARTMENT_ID=""
AVAILABILITY_DOMAIN=""
DISPLAY_NAME="capacity-reservation"
CONFIGS_FILE="$script_dir/reservation-configs.example.json"
PROFILE="DEFAULT"
# Leave blank to use the region configured for PROFILE in ~/.oci/config.
REGION=""
DEFAULT_RESERVATION=false
# Optional: when this OCID exists, update it rather than creating a reservation.
CAPACITY_RESERVATION_ID=""

usage() {
  cat <<'EOF'
Usage:
  create_capacity_reservation.sh \
    --compartment-id <compartment-ocid> \
    --availability-domain <availability-domain-name> \
    --display-name <reservation-name> \
    --configs <path-to-json> \
    [--profile <oci-profile>] [--region <oci-region>] [--default-reservation] \
    [--capacity-reservation-id <capacity-reservation-ocid>]

The JSON file must contain an array of instance reservation configurations.
See reservation-configs.example.json for an example.
EOF
}

compartment_id="$COMPARTMENT_ID"
availability_domain="$AVAILABILITY_DOMAIN"
display_name="$DISPLAY_NAME"
configs_file="$CONFIGS_FILE"
profile="$PROFILE"
region="$REGION"
default_reservation="$DEFAULT_RESERVATION"
capacity_reservation_id="$CAPACITY_RESERVATION_ID"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --compartment-id) compartment_id="${2:-}"; shift 2 ;;
    --availability-domain) availability_domain="${2:-}"; shift 2 ;;
    --display-name) display_name="${2:-}"; shift 2 ;;
    --configs) configs_file="${2:-}"; shift 2 ;;
    --profile) profile="${2:-}"; shift 2 ;;
    --region) region="${2:-}"; shift 2 ;;
    --capacity-reservation-id) capacity_reservation_id="${2:-}"; shift 2 ;;
    --default-reservation) default_reservation=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for required in compartment_id availability_domain display_name configs_file; do
  if [[ -z "${!required}" ]]; then
    echo "Missing required option: --${required//_/-}" >&2
    usage >&2
    exit 2
  fi
done

command -v oci >/dev/null || { echo "OCI CLI is not installed or not on PATH." >&2; exit 1; }
[[ -f "$configs_file" ]] || { echo "Configuration file not found: $configs_file" >&2; exit 1; }

# The OCI CLI accepts a file:// URI. Convert a relative path so the URI is valid.
configs_path="$(cd "$(dirname "$configs_file")" && pwd)/$(basename "$configs_file")"

# Fail early on malformed JSON. OCI still validates shape availability and limits.
python3 -m json.tool "$configs_path" >/dev/null

profile_args=()
[[ -n "$profile" ]] && profile_args=(--profile "$profile")
[[ -n "$region" ]] && profile_args+=(--region "$region")

if [[ -n "$capacity_reservation_id" ]] && \
  oci "${profile_args[@]}" compute capacity-reservation get \
    --capacity-reservation-id "$capacity_reservation_id" >/dev/null 2>&1; then
  # OCI treats this as the complete desired set. Configurations absent from
  # the JSON file are removed from the existing reservation.
  echo "Updating existing capacity reservation '$capacity_reservation_id'..."
  oci "${profile_args[@]}" compute capacity-reservation update \
    --capacity-reservation-id "$capacity_reservation_id" \
    --display-name "$display_name" \
    --instance-reservation-configs "file://$configs_path" \
    --wait-for-state SUCCEEDED
else
  echo "Creating capacity reservation '$display_name' in $availability_domain..."
  create_args=(
    compute capacity-reservation create
    --compartment-id "$compartment_id"
    --availability-domain "$availability_domain"
    --display-name "$display_name"
    --instance-reservation-configs "file://$configs_path"
    --wait-for-state ACTIVE
  )
  [[ "$default_reservation" == true ]] && create_args+=(--is-default-reservation true)
  oci "${profile_args[@]}" "${create_args[@]}"
fi
