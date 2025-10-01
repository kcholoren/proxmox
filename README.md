# Script para servidores virtualizados con Proxmox
## Verificar periódicamente el uso de disco
Debe correrse con cron, por ejemplo, cada 10 minutos:

`
*/10 * * * * /root/check_proxmox_disk_usage.sh
`

Ejemplo de un correo enviado:
<img src="doc/Alerta_VMs_LXC_con_uso_de_disco_80_en_Proxmox.png" alt="A screenshot of an email sent by the script">
