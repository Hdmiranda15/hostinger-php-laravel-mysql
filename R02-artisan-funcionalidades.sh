#!/bin/bash

# ------------------------------------------------------------------------------
# Script: generate_laravel_features.sh
# Descripción: Genera y configura componentes de Laravel para funcionalidades
#              específicas del sitio web personal, basándose en los requerimientos.
#              Ignora cualquier dependencia de frontend.
# Ejecutar dentro de la raíz del proyecto Laravel.
# ------------------------------------------------------------------------------

# --- Configuración de manejo de errores ---
set -euo pipefail

# --- Funciones de Logging ---
log() { echo "[INFO] $1"; }
success() { echo "[SUCCESS] $1"; }
error() { echo "[ERROR] $1" >&2; }
warning() { echo "[WARNING] $1" >&2; }

# --- Verificación Inicial ---
if [ ! -f "artisan" ]; then
    error "El archivo artisan no se encuentra. Asegúrate de ejecutar este script en la raíz de tu proyecto Laravel."
    exit 1
fi

# --- Funciones auxiliares ---
# Verifica si una línea existe en un archivo
line_exists_in_file() {
    local line="$1"
    local file="$2"
    grep -Fxq "$line" "$file"
}

# Inserta una línea después de un patrón si la línea no existe ya
# Usa # como delimitador para sed y escapa caracteres especiales para sed
insert_line_after_pattern_safe() {
    local pattern="$1"
    local line_to_insert="$2"
    local file="$3"

    if ! line_exists_in_file "$line_to_insert" "$file"; then
        # Escapar caracteres que podrían ser interpretados por sed
        local escaped_pattern=$(printf '%s\n' "$pattern" | sed 's/[][\\/.^$*()]/\\&/g')
        local escaped_line=$(printf '%s\n' "$line_to_insert" | sed 's/[][\\/.^$*()]/\\&/g')
        # Usamos # como delimitador para sed, que es menos común y evita problemas con paths
        sed -i "\#$escaped_pattern#a $escaped_line" "$file"
        log "Línea añadida: '$line_to_insert' en '$file'"
    else
        log "La línea ya existe: '$line_to_insert' en '$file'"
    fi
}

# --- Generación de Componentes Específicos ---

generate_specific_features() {
    log "--- Iniciando generación de funcionalidades específicas (PHP/Laravel) ---"

    # --- 2. Requerimientos de "Sobre Mí" ---
    log "Configurando funcionalidades para 'Sobre Mí'..."
    # Para la foto profesional, se asume que se añadirá un campo al modelo User.
    # Aquí verificamos si el modelo User existe y si la línea de fillable está presente.
    USER_MODEL="app/Models/User.php"
    if [ -f "$USER_MODEL" ]; then
        log "Verificando Modelo User (app/Models/User.php)..."
        # Añadir 'profile_photo_path' al $fillable si no existe
        if ! grep -q "'profile_photo_path'," "$USER_MODEL"; then
            insert_line_after_pattern_safe "protected \$fillable = \[" "'    \'profile_photo_path\',' "$USER_MODEL"
        else
            log "El campo 'profile_photo_path' ya está en el array \$fillable del Modelo User."
        fi
        # Añadir el accessor para la URL de la foto si no existe
        if ! grep -q "public function getProfilePhotoUrlAttribute()" "$USER_MODEL"; then
            # Insertar después del último '}' de un método para evitar problemas de sintaxis
            # Buscamos el final de un método para insertar nuestro código. Si User.php es generado por Fortify/Jetstream,
            # puede tener varios métodos. Insertamos al final del archivo por simplicidad.
            # Una alternativa más robusta sería buscar el final de la clase.
            cat <<'EOF' >> "$USER_MODEL"

    /**
     * Obtiene la URL de la foto de perfil.
     * Asume que las fotos se guardan en storage/app/public/profile/
     * y que 'php artisan storage:link' está ejecutado.
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
            success "Accessor 'profile_photo_url' añadido al Modelo User."
        else
            log "El accessor 'profile_photo_url' ya existe en el Modelo User."
        fi
    else
        warning "El Modelo User (app/Models/User.php) no fue encontrado. Asegúrate de que exista para la gestión de la foto de perfil."
    fi

    # --- 3. Requerimientos de "Servicios" ---
    log "Configurando funcionalidades para 'Servicios'..."
    # El Modelo Service y su migración ya fueron generados en el script 1.
    # Ahora, en el Modelo Service, añadiremos los accesores y relaciones si son necesarios.
    SERVICE_MODEL="app/Models/Service.php"
    if [ -f "$SERVICE_MODEL" ]; then
        log "Actualizando Modelo Service (app/Models/Service.php)..."
        # Añadir accessor para el icono si se va a usar Font Awesome o similar
        if ! grep -q "public function getIconAttribute(" "$SERVICE_MODEL"; then
            insert_line_after_pattern_safe "protected \$dates = \['deleted_at'\];" "
    /**
     * Devuelve el HTML del icono (ej: para Font Awesome).
     * @return string
     */
    public function getIconAttribute(\$value)
    {
        // Si el valor es un nombre de clase de Font Awesome, devuélvelo.
        // Si fuera un path a una imagen, devolverías url('/img/services/' . \$value);
        return '<i class=\"' . \$value . '\"></i>'; // Ejemplo para Font Awesome
    }
}
" "$SERVICE_MODEL"
        else
            log "El accessor 'icon' ya existe en el Modelo Service."
        fi
    else
        error "El Modelo Service no se encontró. Algo salió mal en el script 1."
    fi

    # --- 4. Requerimientos de "Portafolio" ---
    log "Configurando funcionalidades para 'Portafolio'..."
    # El Modelo Project ya fue generado en el script 1.
    PROJECT_MODEL="app/Models/Project.php"
    if [ -f "$PROJECT_MODEL" ]; then
        log "Actualizando Modelo Project (app/Models/Project.php)..."
        # Añadir acceso a imágenes de galería y manejo de tecnologías (ya hecho con JSON en el script 1).
        # Podríamos añadir un método para obtener la galería de imágenes si se guarda como un JSON de rutas.
        # Por ahora, las rutas de galería se manejarán en la lógica del controlador/vista.
        # Verificamos que el accessor para main_image exista.
        if ! grep -q "public function getMainImageUrlAttribute()" "$PROJECT_MODEL"; then
            insert_line_after_pattern_safe "protected \$dates = \['deleted_at', 'date_completed'\];" "
    public function getMainImageUrlAttribute()
    {
        if (\$this->main_image) {
            // Asumiendo que las imágenes de proyecto se guardan en storage/app/public/projects/images
            // y que 'php artisan storage:link' está ejecutado.
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
        error "El Modelo Project no se encontró. Algo salió mal en el script 1."
    fi

    # --- 5. Requerimientos del BLOG (Adicionales) ---
    log "Configurando funcionalidades adicionales para el BLOG..."
    POST_MODEL="app/Models/Post.php"
    if [ -f "$POST_MODEL" ]; then
        log "Actualizando Modelo Post (app/Models/Post.php)..."
        # Añadir relación con User (ya está)
        # Añadir relaciones con Category y Tag (ya están)

        # Resumen automático (ya está en el boot del modelo)
        # Carga de imagen destacada única -> se maneja en el controlador/Job.
        # Múltiples imágenes adicionales dentro del contenido -> esto requiere lógica de guardado y guardado en el contenido (ej. Markdown o HTML).
        # Se dejará para implementación manual o un script más avanzado.

        # Búsqueda avanzada por palabra clave -> lógica en BlogController.
        # Entradas recientes y populares -> lógica en BlogController.
        # Comentarios con moderación -> requiere Models, Migrations, Controllers, Views para comentarios.

        # Añadir la función `neighbor` para navegación de posts (si no existe)
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
            log "El método 'neighbor' ya existe en el Modelo Post."
        fi
    else
        error "El Modelo Post no se encontró. Algo salió mal en el script 1."
    fi

    # --- 6. Requerimientos Técnicos Laravel + Funcionalidades Avanzadas ---
    log "Configurando Requerimientos Técnicos y Funcionalidades Avanzadas..."

    # Autenticación de Laravel: Asumimos que ya está configurada con Laravel Breeze/Jetstream o similar.
    # Si no, se podría añadir un comando: php artisan ui bootstrap --auth (para Laravel < 7)
    # o usar Breeze/Jetstream.

    # Laravel Storage para manejo de archivos multimedia:
    # Se han añadido los accesores en los modelos para acceder a las URLs de las imágenes.
    # La estructura de directorios en public/ storage ya se verificó/creó en el script 1.
    # Asegúrate de ejecutar 'php artisan storage:link' manualmente si no se hizo.
    log "Asegúrate de haber ejecutado 'php artisan storage:link' para que las imágenes sean accesibles."

    # Laravel Jobs para procesamiento en segundo plano (ej. imágenes):
    log "Generando Job de ejemplo para procesamiento de imágenes de POST..."
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
        // Generar nombre de archivo único
        $filename = Str::random(40) . '.' . pathinfo($originalPath, PATHINFO_EXTENSION);
        $storageDisk = 'public'; // Corresponde a la carpeta public/
        $storagePath = 'posts/images/' . $filename; // Destino final en public/storage/posts/images

        try {
            // Procesar la imagen usando Intervention Image
            // Asegúrate de haber ejecutado: composer require intervention/image
            $img = Image::make($originalPath);

            // Redimensionar a un ancho máximo, manteniendo la proporción
            $img->resize(1200, null, function ($constraint) {
                $constraint->aspectRatio();
                $constraint->upsize(); // No aumentar tamaño si es menor
            });

            // Guardar en el disco 'public'
            // Asegúrate de que la carpeta exista: public/storage/posts/images
            // Si usas storage:link, esto mapeará a public/posts/images
            Storage::disk($storageDisk)->put($storagePath, (string) $img->encode('jpg', 85)); // Guardar como JPG con calidad 85

            // Actualizar el modelo Post con el nombre de la nueva imagen
            $this->post->image = $filename; // Guardar solo el nombre del archivo
            $this->post->save();

            // Opcional: eliminar el archivo temporal si se usó uno que no es de disco temporal
            // if (Storage::disk('local')->exists($originalPath)) { // Si se guardó en storage/app/local/temporal
            //     Storage::disk('local')->delete($originalPath);
            // }

        } catch (\Exception $e) {
            // Log del error o manejo de fallo
            logger()->error("Error processing post image for post ID {$this->post->id}: " . $e->getMessage());
            // Opcional: eliminar el post si la imagen era obligatoria y falló
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

    # Comentarios con moderación:
    # Esto requiere la creación de Modelos (Comment, Reply), Migraciones,
    # Relaciones, Controladores y Vistas. Se deja como una tarea para el desarrollo futuro.
    # Se podría generar aquí una estructura base si se desea.

    log "--- Generación de funcionalidades específicas completada ---"
    log "Próximos pasos recomendados:"
    log "1. Ejecuta las migraciones pendientes: php artisan migrate"
    log "2. Si usaste Intervention Image, asegúrate de instalarla: composer require intervention/image"
    log "3. Si necesitas la autenticación de Laravel (ej. registro/login), considera instalar Breeze: composer require laravel/breeze && php artisan breeze:install"
    log "4. Para probar los componentes generados, puedes poblar las tablas con datos de ejemplo usando Tinker:"
    log "   php artisan tinker"
    log "   => \App\Models\Category::factory(3)->create();"
    log "   => \App\Models\Tag::factory(5)->create();"
    log "   => \App\Models\Service::factory(4)->create();"
    log "   => \App\Models\Project::factory(5)->create(['user_id' => 1]);" # Asume que el User ID 1 existe
    log "   => \App\Models\Post::factory(10)->create(['user_id' => 1]);" # Asume que el User ID 1 existe
    log "   (Puede que necesites crear Factories para los modelos si aún no existen)."
    log "5. Asegúrate de que 'php artisan storage:link' esté ejecutado para que las imágenes sean accesibles."
}

# --- Ejecución Principal ---
generate_specific_features

exit 0