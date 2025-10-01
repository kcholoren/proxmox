#!/bin/bash

# Configuración
THRESHOLD=85                    # Umbral de uso de disco en %
EXCLUDE_VMS=("138" "201") # IDs de VMs/LXC a excluir 
EMAIL="name@hosting"     # Correo destino
SUBJECT="Alerta: VMs/LXC con uso de disco > ${THRESHOLD}% en Proxmox"

# Archivo temporal para almacenar resultados
TEMP_FILE=$(mktemp)

# Convertimos la lista de exclusión a números en jq
EXCLUDE_JSON=$(printf '%s\n' "${EXCLUDE_VMS[@]}" | jq -R 'tonumber' | jq -s .)

# Obtener VMs/LXC que superan el umbral y no están excluidas
pvesh get /cluster/resources --type vm --output-format json-pretty | \
jq -r --argjson threshold "$THRESHOLD" --argjson exclude "$EXCLUDE_JSON" '
  .[] |
  select(.type == "qemu" or .type == "lxc") |
  select(.disk != null and .maxdisk != null and .maxdisk > 0) |
  (.disk / .maxdisk * 100) as $usage |
  select($usage > $threshold) |
  select([.vmid] | inside($exclude) | not) |
  "\(.name)\t\($usage | floor)%\t\(.mem // 0)\t\(.uptime // 0)\t\(.vmid)"
' > "$TEMP_FILE"

# Verificar si hay resultados
if [ -s "$TEMP_FILE" ]; then

    # Construir tabla HTML
    {
        cat << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<body style="font-family: Arial, sans-serif; margin: 20px; background-color: #f9f9f9;">
    <div style="max-width: 800px; margin: auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1);">
        <h2 style="color: #d9534f; border-bottom: 2px solid #d9534f; padding-bottom: 10px;">Alerta: VMs/LXC con uso de disco > THRESHOLD%</h2>
        <p>Las siguientes máquinas virtuales o contenedores superan el límite de uso de disco:</p>
        <table style="width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 14px;">
            <thead>
                <tr style="background-color: #f1f1f1;">
                    <th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Nombre</th>
                    <th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Disco Usado</th>
                    <th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Memoria</th>
                    <th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Uptime</th>
                    <th style="padding: 10px; text-align: left; border: 1px solid #ddd;">ID</th>
                </tr>
            </thead>
            <tbody>
EOF

        while IFS=$'\t' read -r name disk mem uptime vmid; do
            mem_mb=$((mem / 1024 / 1024))
            days=$((uptime / 86400))
            hours=$(((uptime % 86400) / 3600))
            mins=$(((uptime % 3600) / 60))
            uptime_str="${days}d ${hours}h ${mins}m"

            cat << EOF
                <tr>
                    <td style="padding: 10px; border: 1px solid #ddd;">$name</td>
                    <td style="padding: 10px; border: 1px solid #ddd; color: #d9534f; font-weight: bold;">$disk</td>
                    <td style="padding: 10px; border: 1px solid #ddd;">${mem_mb} MB</td>
                    <td style="padding: 10px; border: 1px solid #ddd;">$uptime_str</td>
                    <td style="padding: 10px; border: 1px solid #ddd;">$vmid</td>
                </tr>
EOF
        done < "$TEMP_FILE"

        cat << 'EOF'
            </tbody>
        </table>
        <p><small>Generado automáticamente por script de monitoreo Proxmox.</small></p>
    </div>
</body>
</html>
EOF
    } | sed "s/THRESHOLD/$THRESHOLD/g" > "${TEMP_FILE}.html"

    # Enviar correo en formato HTML
    # 'mail' con soporte HTML:
    mail -a "Content-Type: text/html; charset=UTF-8" -s "$SUBJECT" "$EMAIL" < "${TEMP_FILE}.html"
fi

# Limpiar
rm -f "$TEMP_FILE" "${TEMP_FILE}.html"
