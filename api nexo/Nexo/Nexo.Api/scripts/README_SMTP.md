# SMTP real con Gmail

Para enviar códigos reales por correo con Gmail:

1. Activa la verificación en 2 pasos de tu cuenta Google.
2. Entra a https://myaccount.google.com/apppasswords
3. Crea una App Password para `Nexo SMTP`.
4. Copia la contraseña de 16 caracteres sin espacios.
5. Copia `run-with-gmail-smtp.example.sh` a `run-with-gmail-smtp.local.sh`.
6. Reemplaza `Email__Username`, `Email__Password` y `Email__From`.
7. Ejecuta:

```bash
./scripts/run-with-gmail-smtp.local.sh
```

Gmail SMTP:

```text
Host: smtp.gmail.com
Port: 587
TLS/SSL: true
Username: tu correo completo
Password: App Password de Google, no tu contraseña normal
```
