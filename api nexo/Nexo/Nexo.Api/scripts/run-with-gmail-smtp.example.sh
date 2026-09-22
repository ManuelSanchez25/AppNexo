#!/usr/bin/env bash
set -euo pipefail

# Copia este archivo a run-with-gmail-smtp.local.sh y pon tus datos reales.
# No subas el archivo local con contraseña.
export Email__SmtpHost="smtp.gmail.com"
export Email__SmtpPort="587"
export Email__EnableSsl="true"
export Email__Username="tu_correo@gmail.com"
export Email__Password="tu_app_password_de_16_digitos_sin_espacios"
export Email__From="tu_correo@gmail.com"

cd "$(dirname "$0")/.."
dotnet run --urls "http://0.0.0.0:5046"
