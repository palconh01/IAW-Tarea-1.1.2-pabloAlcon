#!/bin/bash
apt-get update -y
apt-get install -y apache2
systemctl enable apache2
systemctl start apache2

cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Practica Vagrant</title>
</head>
<body>
    <h1>Servidor Apache funcionando</h1>
    <p>Alumno: Pablo Alcon</p>
    <p>Hostname de la maquina:$(hostname)</p>
</body>
</html>
EOF