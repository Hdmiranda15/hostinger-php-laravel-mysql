#!/bin/bash

# ------------------------------------------------------------------------------
# Script: generate_laravel_features.sh
# Descripci�n: Genera y configura componentes de Laravel para funcionalidades
#              espec�ficas del sitio web personal, bas�ndose en los requerimientos.
#              Ignora cualquier dependencia de frontend.
# Ejecutar dentro de la ra�z del proyecto Laravel.
# ------------------------------------------------------------------------------

# --- Configuraci�n de manejo de errores ---
set -euo pipefail

# --- Funciones de Logging ---
log() { echo "[INFO] $1"; }
success() { echo "[SUCCESS] $1"; }
error() { echo "[ERROR] $1" >&2; }
warning() { echo "[WARNING] $1" >&2; }

# --- Verificaci�n Inicial ---
if [ ! -f "artisan" ]; then
    error "El archivo artisan no se encuentra. Aseg�rate de ejecutar este script en la ra�z de tu proyecto Laravel."
    exit 1
fi

# --- Funciones auxiliares ---
# Verifica si una l�nea existe en un archivo
line_exists_in_file() {
    local line="$1"
    local file="$2"
    grep -Fxq "$line" "$file"
}

# Inserta una l�nea despu�s de un patr�n si la l�nea no existe ya
# Usa # como delimitador para sed y escapa caracteres especiales para sed
insert_line_after_pattern_safe() {
    local pattern="$1"
    local line_to_insert="$2"
    local file="$3"

    if ! line_exists_in_file "$line_to_insert" "$file"; then
        # Escapar caracteres que podr�an ser interpretados por sed
        local escaped_pattern=$(printf '%s\n' "$pattern" | sed 's/[][\\/.^$*()]/\\&/g')
        local escaped_line=$(printf '%s\n' "$line_to_insert" | sed 's/[][\\/.^$*()]/\\&/g')
        # Usamos # como delimitador para sed, que es menos com�n y evita problemas con paths
        sed -i "\#$escaped_pattern#a $escaped_line" "$file"
        log "L�nea a�adida: '$line_to_insert' en '$file'"
    else
        log "La l�nea ya existe: '$line_to_insert' en '$file'"
    fi
}

# --- Generaci�n de Componentes Espec�ficos ---

generate_specific_features() {
    log "--- Iniciando generaci�n de funcionalidades espec�ficas (PHP/Laravel) ---"

    # --- 2. Requerimientos de "Sobre M�" ---
    log "Configurando funcionalidades para 'Sobre M�'..."
    # Para la foto profesional, se asume que se a�adir� un campo al modelo User.
    # Aqu� verificamos si el modelo User existe y si la l�nea de fillable est� presente.
    USER_MODEL="app/Models/User.php"
    if [ -f "$USER_MODEL" ]; then
        log "Verificando Modelo User (app/Models/User.php)..."
        # A�adir 'profile_photo_path' al $fillable si no existe
        if ! grep -q "'profile_photo_path'," "$USER_MODEL"; then
            insert_line_after_pattern_safe "protected \$fillable = \[" "'    \'profile_photo_path\',' "$USER_MODEL"
        else
            log "El campo 'profile_photo_path' ya est� en el array \$fillable del Modelo User."
        fi
        # A�adir el accessor para la URL de la foto si no existe
        if ! grep -q "public function getProfilePhotoUrlAttribute()" "$USER_MODEL"; then
            # Insertar despu�s del �ltimo '}' de un m�todo para evitar problemas de sintaxis
            # Buscamos el final de un m�todo para insertar nuestro c�digo. Si User.php es generado por Fortify/Jetstream,
            # puede tener varios m�todos. Insertamos al final del archivo por simplicidad.
            # Una alternativa m�s robusta ser�a buscar el final de la clase.
            cat <<'EOF' >> "$USER_MODEL"

    /**
     * Obtiene la URL de la foto de perfil.
     * Asume que las fotos se guardan en storage/app/public/profile/
     * y que 'php artisan storage:link' est� ejecutado.
     *
     * @return string|null
     */
    public function getProfilePhotoUrlAttribute()
    {
        if ($this->profile_photo_path) {
            return url('/storage/profile/' . $this->profile_photo_path);
        }
        // Puedes devolver una URL de imagen por defecto si profile_photo_path es nulo
        // return asset('img/default-avatar.png');
        return null;
    }
}
EOF
            success "Accessor 'profile_photo_url' a�adido al Modelo User."
        else
            log "El accessor 'profile_photo_url' ya existe en el Modelo User."
        fi
    else
        warning "El Modelo User (app/Models/User.php) no fue encontrado. Aseg�rate de que exista para la gesti�n de la foto de perfil."
    fi

    # --- 3. Requerimientos de "Servicios" ---
    log "Configurando funcionalidades para 'Servicios'..."
    # El Modelo Service y su migraci�n ya fueron generados en el script 1.
    # Ahora, en el Modelo Service, a�adiremos los accesores y relaciones si son necesarios.
    SERVICE_MODEL="app/Models/Service.php"
    if [ -f "$SERVICE_MODEL" ]; then
        log "Actualizando Modelo Service (app/Models/Service.php)..."
        # A�adir accessor para el icono si se va a usar Font Awesome o similar
        if ! grep -q "public function getIconAttribute(" "$SERVICE_MODEL"; then
            insert_line_after_pattern_safe "protected \$dates = \['deleted_at'\];" "
    /**
     * Devuelve el HTML del icono (ej: para Font Awesome).
     * @return string
     */
    public function getIconAttribute(\$value)
    {
        // Si el valor es un nombre de clase de Font Awesome, devu�lvelo.
        // Si fuera un path a una imagen, devolver�as url('/img/services/' . \$value);
        return '<i class=\"' . \$value . '\"></i>'; // Ejemplo para Font Awesome
    }
}
" "$SERVICE_MODEL"
        else
            log "El accessor 'icon' ya existe en el Modelo Service."
        fi
    else
        error "El Modelo Service no se encontr�. Algo sali� mal en el script 1."
    fi

    # --- 4. Requerimientos de "Portafolio" ---
    log "Configurando funcionalidades para 'Portafolio'..."
    # El Modelo Project ya fue generado en el script 1.
    PROJECT_MODEL="app/Models/Project.php"
    if [ -f "$PROJECT_MODEL" ]; then
        log "Actualizando Modelo Project (app/Models/Project.php)..."
        # A�adir acceso a im�genes de galer�a y manejo de tecnolog�as (ya hecho con JSON en el script 1).
        # Podr�amos a�adir un m�todo para obtener la galer�a de im�genes si se guarda como un JSON de rutas.
        # Por ahora, las rutas de galer�a se manejar�n en la l�gica del controlador/vista.
        # Verificamos que el accessor para main_image exista.
        if ! grep -q "public function getMainImageUrlAttribute()" "$PROJECT_MODEL"; then
            insert_line_after_pattern_safe "protected \$dates = \['deleted_at', 'date_completed'\];" "
    public function getMainImageUrlAttribute()
    {
        if (\$this->main_image) {
            // Asumiendo que las im�genes de proyecto se guardan en storage/app/public/projects/images
            // y que 'php artisan storage:link' est� ejecutado.
            return url('/storage/projects/images/' . \$this->main_image);
        }
        return null; // O una imagen por defecto
    }
}
" "$PROJECT_MODEL"
        else
            log "El accessor 'main_image_url' ya existe en el Modelo Project."
        fi
    else
        error "El Modelo Project no se encontr�. Algo sali� mal en el script 1."
    fi

    # --- 5. Requerimientos del BLOG (Adicionales) ---
    log "Configurando funcionalidades adicionales para el BLOG..."
    POST_MODEL="app/Models/Post.php"
    if [ -f "$POST_MODEL" ]; then
        log "Actualizando Modelo Post (app/Models/Post.php)..."
        # A�adir relaci�n con User (ya est�)
        # A�adir relaciones con Category y Tag (ya est�n)

        # Resumen autom�tico (ya est� en el boot del modelo)
        # Carga de imagen destacada �nica -> se maneja en el controlador/Job.
        # M�ltiples im�genes adicionales dentro del contenido -> esto requiere l�gica de guardado y guardado en el contenido (ej. Markdown o HTML).
        # Se dejar� para implementaci�n manual o un script m�s avanzado.

        # B�squeda avanzada por palabra clave -> l�gica en BlogController.
        # Entradas recientes y populares -> l�gica en BlogController.
        # Comentarios con moderaci�n -> requiere Models, Migrations, Controllers, Views para comentarios.

        # A�adir la funci�n `neighbor` para navegaci�n de posts (si no existe)
        if ! grep -q "public function neighbor(" "$POST_MODEL"; then
            insert_line_after_pattern_safe "public function getImageUrlAttribute()" "
    /**
     * Navega entre posts adyacentes (anterior/siguiente).
     * @param string \$direction 'previous' or 'next'
     * @return \App\Models\Post|null
     */
    public function neighbor(string \$direction = 'next')
    {
        if (\$direction === 'previous') {
            return static::where('published_at', '<', \$this->published_at)
                         ->whereNotNull('published_at')
                         ->orderBy('published_at', 'desc')
                         ->first();
        } else { // next
            return static::where('published_at', '>', \$this->published_at)
                         ->whereNotNull('published_at')
                         ->orderBy('published_at', 'asc')
                         ->first();
        }
    }
}
" "$POST_MODEL"
        else
            log "El m�todo 'neighbor' ya existe en el Modelo Post."
        fi
    else
        error "El Modelo Post no se encontr�. Algo sali� mal en el script 1."
    fi

    # --- 6. Requerimientos T�cnicos Laravel + Funcionalidades Avanzadas ---
    log "Configurando Requerimientos T�cnicos y Funcionalidades Avanzadas..."

    # Autenticaci�n de Laravel: Asumimos que ya est� configurada con Laravel Breeze/Jetstream o similar.
    # Si no, se podr�a a�adir un comando: php artisan ui bootstrap --auth (para Laravel < 7)
    # o usar Breeze/Jetstream.

    # Laravel Storage para manejo de archivos multimedia:
    # Se han a�adido los accesores en los modelos para acceder a las URLs de las im�genes.
    # La estructura de directorios en public/ storage ya se verific�/cre� en el script 1.
    # Aseg�rate de ejecutar 'php artisan storage:link' manualmente si no se hizo.
    log "Aseg�rate de haber ejecutado 'php artisan storage:link' para que las im�genes sean accesibles."

    # Laravel Jobs para procesamiento en segundo plano (ej. im�genes):
    log "Generando Job de ejemplo para procesamiento de im�genes de POST..."
    if [ ! -f "app/Jobs/ProcessPostImage.php" ]; then
        php artisan make:job ProcessPostImage
        success "Job ProcessPostImage generado."

        # Configurar Job ProcessPostImage (app/Jobs/ProcessPostImage.php)
        cat <<'EOF' > app/Jobs/ProcessPostImage.php
<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Intervention\Image\ImageManagerStatic as Image; // Requiere: composer require intervention/image

class ProcessPostImage implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $post;
    protected $imagePath; // Ruta temporal de la imagen subida (ej: de /tmp o similar)

    /**
     * Create a new job instance.
     *
     * @param \App\Models\Post $post
     * @param string $imagePath Ruta de la imagen temporal a procesar
     * @return void
     */
    public function __construct($post, $imagePath)
    {
        $this->post = $post;
        $this->imagePath = $imagePath;
    }

    /**
     * Execute the job.
     *
     * @return void
     */
    public function handle()
    {
        $originalPath = $this->imagePath;
        // Generar nombre de archivo �nico
        $filename = Str::random(40) . '.' . pathinfo($originalPath, PATHINFO_EXTENSION);
        $storageDisk = 'public'; // Corresponde a la carpeta public/
        $storagePath = 'posts/images/' . $filename; // Destino final en public/storage/posts/images

        try {
            // Procesar la imagen usando Intervention Image
            // Aseg�rate de haber ejecutado: composer require intervention/image
            $img = Image::make($originalPath);

            // Redimensionar a un ancho m�ximo, manteniendo la proporci�n
            $img->resize(1200, null, function ($constraint) {
                $constraint->aspectRatio();
                $constraint->upsize(); // No aumentar tama�o si es menor
            });

            // Guardar en el disco 'public'
            // Aseg�rate de que la carpeta exista: public/storage/posts/images
            // Si usas storage:link, esto mapear� a public/posts/images
            Storage::disk($storageDisk)->put($storagePath, (string) $img->encode('jpg', 85)); // Guardar como JPG con calidad 85

            // Actualizar el modelo Post con el nombre de la nueva imagen
            $this->post->image = $filename; // Guardar solo el nombre del archivo
            $this->post->save();

            // Opcional: eliminar el archivo temporal si se us� uno que no es de disco temporal
            // if (Storage::disk('local')->exists($originalPath)) { // Si se guard� en storage/app/local/temporal
            //     Storage::disk('local')->delete($originalPath);
            // }

        } catch (\Exception $e) {
            // Log del error o manejo de fallo
            logger()->error("Error processing post image for post ID {$this->post->id}: " . $e->getMessage());
            // Opcional: eliminar el post si la imagen era obligatoria y fall�
            // $this->post->delete();
        }
    }
}
EOF
        success "Job ProcessPostImage configurado."
        log "NOTA: Para que el Job ProcessPostImage funcione, necesitas instalar Intervention Image:"
        log "Ejecuta: composer require intervention/image"
    else
        warning "El Job ProcessPostImage ya existe. No se sobrescribe."
    fi

    # Cache de Laravel: Ya se usa en BlogController para entradas populares.
    # Rutas amigables con slugs y SEO: Implementado en los modelos (`slug` y `get...UrlAttribute`).

    # Comentarios con moderaci�n:
    # Esto requiere la creaci�n de Modelos (Comment, Reply), Migraciones,
    # Relaciones, Controladores y Vistas. Se deja como una tarea para el desarrollo futuro.
    # Se podr�a generar aqu� una estructura base si se desea.

    log "--- Generaci�n de funcionalidades espec�ficas completada ---"
    log "Pr�ximos pasos recomendados:"
    log "1. Ejecuta las migraciones pendientes: php artisan migrate"
    log "2. Si usaste Intervention Image, aseg�rate de instalarla: composer require intervention/image"
    log "3. Si necesitas la autenticaci�n de Laravel (ej. registro/login), considera instalar Breeze: composer require laravel/breeze && php artisan breeze:install"
    log "4. Para probar los componentes generados, puedes poblar las tablas con datos de ejemplo usando Tinker:"
    log "   php artisan tinker"
    log "   => \App\Models\Category::factory(3)->create();"
    log "   => \App\Models\Tag::factory(5)->create();"
    log "   => \App\Models\Service::factory(4)->create();"
    log "   => \App\Models\Project::factory(5)->create(['user_id' => 1]);" # Asume que el User ID 1 existe
    log "   => \App\Models\Post::factory(10)->create(['user_id' => 1]);" # Asume que el User ID 1 existe
    log "   (Puede que necesites crear Factories para los modelos si a�n no existen)."
    log "5. Aseg�rate de que 'php artisan storage:link' est� ejecutado para que las im�genes sean accesibles."
}

# --- Ejecuci�n Principal ---
generate_specific_features

exit 0