# Primeros pasos con Vagrant

## Investigación previa

### 1. Vagrant y el Vagrantfile

- **Qué problema resuelve Vagrant:** Evita el problema de que un entorno funcione en un ordenador y falle en otro por diferencias de configuración. Permite definir las características de una máquina virtual en un archivo de texto que se puede guardar en Git para que cualquier persona cree exactamente el mismo servidor con un solo comando.
- **Diferencia entre componentes:**
    - **Anfitrión (Host):** Es mi ordenador físico donde instalo Vagrant y el hipervisor.
    - **Proveedor (Provider):** Es el programa que virtualiza las máquinas por debajo (por ejemplo, VirtualBox o VMware Workstation). Vagrant le da las órdenes a este programa.
    - **Box:** Es la plantilla o imagen base del sistema operativo (en nuestro caso, Debian 12) a partir de la cual se clonan las máquinas virtuales.
    - **Máquina virtual (Guest):** Es el sistema operativo final que ya está creado y corriendo dentro del proveedor.
- **Lenguaje del Vagrantfile:** Está escrito en **Ruby**.

### 2. Aprovisionamiento (Provisioning)

- **Qué es un provisioner:** Es una herramienta de Vagrant que sirve para instalar programas y configurar la máquina automáticamente (por ejemplo, mediante un script Bash) sin tener que entrar a hacerlo a mano.
- **Dónde y cuándo se ejecuta:** El script se ejecuta **dentro de la máquina virtual** (con permisos de superusuario `root`). Vagrant lo lanza automáticamente solo la primera vez que se crea la máquina con `vagrant up`.
- **Diferencia entre `inline:` y `path:`:**
    - `inline:`: Escribes los comandos directamente dentro del propio `Vagrantfile`. Es útil para ordenes sueltas.
    - `path:`: Le indicas la ruta a un archivo `.sh` externo guardado en el proyecto. Es mucho más limpio cuando tienes varias órdenes.
- **Qué pasa si modifico el script tras el primer `vagrant up`:** Si hago `vagrant up` otra vez no se ejecutará, porque la máquina ya está creada. Para forzar que se vuelva a ejecutar el script modificado hay que usar el comando `vagrant provision`  o `vagrant reload --provision` .

### 3. Interfaces y redes

- **Red por defecto en Vagrant:** Configura siempre como primer adaptador (`eth0` o `enp0s3`) una red en modo **NAT**. La utiliza para que la máquina tenga salida a Internet (descargar paquetes) y para conectar por SSH desde el anfitrión mediante un reenvío automático del puerto 22 al 2222 local.
- **Cómo añadir una segunda interfaz con IP fija:** Añadiendo en el `Vagrantfile` la línea `config.vm.network "private_network", ip: "192.168.56.10"`.
- **Comparativa de modos de red:**
    - **NAT:** La máquina sale a Internet a través del anfitrión, pero nadie desde fuera ni otras máquinas pueden iniciar conexiones hacia ella salvo que configuremos un reenvío de puertos.
    - **Red interna (VirtualBox):** Aísla la máquina en un “switch” virtual interno. Solo permite comunicación entre máquinas virtuales conectadas a la misma red interna; **no** hay conexión con el anfitrión ni con Internet.
    - **Red privada (Host-only en VirtualBox):** Crea una red cerrada entre el anfitrión y las máquinas virtuales. Pueden comunicarse entre ellas y con el anfitrión, pero no tienen salida a Internet por esta interfaz.
    - **Red pública (Bridged / Puente):** Conecta la máquina directamente a la red física real (al router de clase o de casa) como si fuera un ordenador más, recibiendo una IP de la misma red local que el anfitrión.
- **Función del reenvío de puertos (Port Forwarding):** Permite abrir un puerto en el anfitrión  para que todo el tráfico que llegue ahí se redirija automáticamente a un puerto de la máquina virtual  a través de la interfaz NAT.
- **Preguntas sobre la segunda interfaz:**
    - *¿Añadir la segunda interfaz elimina la NAT predeterminada?* No, Vagrant mantiene siempre la interfaz NAT en el primer adaptador porque la necesita para controlar la máquina por SSH, y añade la nueva red en un segundo adaptador.
    - *¿El reenvío de puertos crea una interfaz nueva?* No, reutiliza la interfaz NAT que ya existe por defecto.

### 4. Órdenes y carpeta compartida

| Comando | Cuándo se utiliza |  |
| --- | --- | --- |
| `vagrant up` | Para crear y arrancar la máquina virtual por primera vez (o encenderla si estaba apagada). |  |
| `vagrant status` | Para consultar el estado actual de la máquina . |  |
| `vagrant ssh` | Para conectarse por terminal a la máquina virtual sin tener que meter contraseñas. |  |
| `vagrant reload` | Para reiniciar la máquina y aplicar cambios hechos en el `Vagrantfile` |  |
| `vagrant provision` | Para volver a ejecutar los scripts de aprovisionamiento con la máquina ya encendida. |  |
| `vagrant halt` | Para apagar la máquina virtual de forma segura (se . |  |
| `vagrant destroy` | Para borrar por completo la máquina virtual y liberar el espacio en disco. |  |
- **Qué es `/vagrant`:** Es una carpeta compartida que Vagrant monta automáticamente dentro de la máquina virtual y que está sincronizada en tiempo real con el directorio de nuestro proyecto en el anfitrión. Al hacer `ls /vagrant` dentro de Debian aparecen el `Vagrantfile`, el script `provision.sh` y el `README.md`.

---

## Arquitectura de red e interfaces observadas

### Esquema de la arquitectura

```
+-----------------------------------------------------------------------+
| ANFITRION (Mi equipo)                                                 |
|                                                                       |
	|  Navegador Web (127.0.0.1:8080)            Terminal (vagrant ssh)   |
|               |                                     |                 |
+---------------|-------------------------------------|-----------------+
                | Reenvio de puerto (8080 -> 80)      | Reenvio SSH (2222 -> 22)
                +------------------+------------------+
                                   |
                            [ Red NAT ]
                                   |
+----------------------------------|------------------------------------+
| MAQUINA VIRTUAL (Debian 12 - Hostname: debian-PabloAlcon)              |
|                                  |                                    |
|  Interfaz 1 (NAT - eth0/enp0s3)  |         Interfaz 2 (  eth1)        |
|  IP: 10.0.2.15/24                |         IP fija: 192.168.56.10/24  |
|  Gateway: 10.0.2.2               |               (Red interna )       |
|               |                                                       |
|        [ Apache2 :80 ]                                                |
+-----------------------------------------------------------------------+
```

### Relación de direcciones y rutas en Debian

Al ejecutar `ip a` e `ip r` dentro de la máquina observamos:

1. **Interfaz 1 (NAT - `eth0` / `enp0s3`):** Recibe por DHCP la IP `10.0.2.15/24` y configura la ruta por defecto (`default via 10.0.2.2`) para salir a Internet y recibir la conexión SSH y el puerto 8080 reenviado.
2. **Interfaz 2 ( `eth1` / `enp0s8`):** Tiene asignada la IP estática `192.168.56.10/24` que definimos en el `Vagrantfile`, creando una ruta directa para la red `192.168.56.0/24` sin puerta de enlace.

---

## Configuración del Vagrantfile (Parte C)

### Contenido del archivo `Vagrantfile`

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.vm.hostname = "debian-tunombre"

  config.vm.network "private_network", ip: "192.168.56.10", virtualbox__intnet: true

  config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  config.vm.provision "shell", path: "provision.sh"
end
```

### Análisis línea por línea

- `Vagrant.configure("2") do |config|`: Abre el bloque de configuración indicando que usamos la versión 2 de la sintaxis de Vagrant.
- `config.vm.box = "debian/bookworm64"`: Descarga y utiliza la imagen oficial de Debian 12 de 64 bits. Se comprueba dentro de la máquina con `cat /etc/debian_version`.
- `config.vm.hostname = "debian-PabloAlcon"`: Cambia el nombre del equipo en el sistema. Lo añadí para identificar la máquina con mi nombre y se comprueba ejecutando `hostname` por SSH.
- `config.vm.network "private_network", ip: "192.168.56.10", virtualbox__intnet: true`: Añade el segundo adaptador de red con la IP fija `192.168.56.10` en modo red interna de VirtualBox. Se comprueba ejecutando `ip a` dentro de la máquina.
- `config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"`: Reenvía el puerto 80 de la máquina virtual al 8080 de mi equipo escuchando únicamente en `127.0.0.1`. Lo añadí para poder ver la web de Apache desde mi navegador y se comprueba entrando a `http://127.0.0.1:8080`.
- `config.vm.provision "shell", path: "provision.sh"`: Indica a Vagrant que ejecute el script Bash `provision.sh` al iniciar la máquina para instalar Apache automáticamente. Se comprueba viendo que el servicio `apache2` está instalado y activo.
- `end`: Cierra el bloque de configuración de Ruby.

---

## Aprovisionamiento de Apache (Parte D)

### Contenido del script `provision.sh`

```bash
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
    <p>Alumno:PabloAlcon</p>
    <p>Hostname de la maquina:$(hostname)</p>
</body>
</html>
EOF
```

### Explicación de las órdenes del script

- `#!/bin/bash`: Indica al sistema que el archivo debe interpretarse con la shell Bash.
- `apt-get update -y`: Actualiza la lista de paquetes disponibles en los repositorios de Debian sin pedir confirmación.
- `apt-get install -y apache2`: Instala el servidor web Apache aceptando automáticamente la descarga.
- `systemctl enable apache2`: Configura el servicio de Apache para que arranque solo cada vez que se encienda la máquina.
- `systemctl start apache2`: Inicia el servicio de Apache en ese momento.
- `cat <<EOF > /var/www/html/index.html ... EOF`: Sobrescribe el archivo `index.html` por defecto de Apache con nuestro código HTML, inyectando automáticamente el nombre de la máquina mediante la variable `$(hostname)`.

---

## Pruebas de funcionamiento y capturas

### 1. Comprobación de hostname, interfaces y rutas dentro de la máquina

En esta captura se observa tras entrar con `vagrant ssh` que el nombre de la máquina se ha cambiado correctamente, y que cuenta con las dos interfaces configuradas (`10.0.2.15` por NAT y `192.168.56.10` en la segunda interfaz).

Comprobacion de red y hostname

![image.png](img\image.png)

![image.png](img\image1.png)

### 2. Servicio Apache en ejecución dentro de Debian

Con el comando `systemctl status apache2` comprobamos que el script de aprovisionamiento se ha ejecutado sin fallos y el servicio está activo (`active (running)`).

Estado de Apache en Debian

![image.png](img\image2.png)

### 3. Comprobación de la carpeta compartida `/vagrant`

Al listar el directorio `/vagrant` dentro de la máquina virtual vemos los mismos archivos que tenemos en la carpeta del proyecto en el anfitrión.

Carpeta compartida vagrant

![image.png](img\image3.png)

### 4. Acceso a la página web desde el anfitrión

Accediendo desde el navegador del anfitrión a la dirección `http://127.0.0.1:8080`, comprobamos que el reenvío de puertos funciona y nos muestra el HTML personalizado con mi nombre y el hostname de la máquina.

Acceso web desde anfitrion

![image.png](img\image4.png)

![image.png](img\image5.png)

---

## Registro de incidenecias

- *En la creacion del vagrantfile me salte unas comillas y no me pillaba bien la interfaz de red por lo que corregi el archivo y ya se desplegaba correctamente.*

## Fuentes consultadas

- Documentación oficial de Vagrant (HashiCorp Developer): Vagrantfile, Networking, Forwarded Ports, Private Networks y Shell Provisioner.
- Apuntes de clase proporcionados en Moodle.
