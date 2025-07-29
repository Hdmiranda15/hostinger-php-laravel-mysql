

# entrar a root 

su - 
# registrar  al Usuario 

usermod -aG sudo h-debian
# verificar cambios  
groups h-debian


# luego entrar 
   visudo

# dentro de /etc/sudoers.tmp

# registrar 

   h-debian ALL=(ALL:ALL) ALL


#similar 
# User privilege specification
root     ALL=(ALL:ALL) ALL
h-debian ALL=(ALL:ALL) ALL

   
   