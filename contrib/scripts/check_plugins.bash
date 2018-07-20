#!/bin/bash

set -ex
#!/bin/bash


# first load the original ckan entrypoint
# exit with true to ensure the

# temporarily alias exec to true so we can "extend" this entrypoint
alias exec=true
# source the original entrypoint with aliased exec
. /ckan-entrypoint.sh
unalias exec

google_analytics_enabled=${GA_ENABLED:-}
config="${1:-/etc/ckan/production.ini}"

function setup_google_analytics {
       "ckan-paster" --plugin=ckan config-tool "$config" \
            "googleanalytics.id=${GA_ID}" \
            "googleanalytics.account=${GA_ACCOUNT}" \
            "googleanalytics.username=${GA_USERNAME}" \
            "googleanalytics.password=${GA_PASSWORD}" \
            "googleanalytics.track_events=true" 
}

# get the original list of plugins after equals sign
# (hopefully not newline separated
plugins_orig=$(grep -Po --color '(?<=^ckan\.plugins)\s*=.*$' "$config" |\
               sed 's/^\s*=\s*//')

#ioos_waf
#ckan-harvester
missing_plugins=$(comm -13 <(sort <<< "${plugins_orig// /$'\n'}") <(sort <<EOF
ioos_theme
spatial_metadata
spatial_query
EOF
) | tr "\n" ' ' | sed 's/ $//')

if [[ -n "$missing_plugins" ]]; then
    new_plugins_line="$plugins_orig $missing_plugins"
    
    ckan-paster --plugin=ckan config-tool "$config" -e \
                          "ckan.plugins = $new_plugins_line"
fi

#ckan-paster --plugin=ckan config-tool "$config" "ckan.tracking_enabled = true"

ckan-paster --plugin=ckan config-tool "$config" "ckan.tracking_enabled = true"
if [[ "$google_analytics_enabled" = true ]]; then
    setup_google_analytics
fi

ckan-paster --plugin=ckan db init -c "$config"
ckan-paster --plugin=ckanext-spatial spatial initdb -c "$config"
ckan-paster --plugin=ckanext-harvest harvester initdb -c "$config"
ckan-paster --plugin=ckanext-googleanalytics initdb -c "$config" 

exec "$@"
