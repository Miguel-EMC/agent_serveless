# terraform/bootstrap

**Correr una vez, primero. Antes que cualquier otra cosa de Terraform.**

Este directorio es una raíz de Terraform **separada** del stack principal.
Crea los dos recursos de los que depende todo lo demás:

- un bucket S3 para el remote state (versionado + bloqueo de acceso público)
- una tabla DynamoDB para el locking del state (clave primaria `LockID`)

## Por qué usa state LOCAL (sin backend `s3`)

Problema del huevo y la gallina: el backend `s3` necesita un bucket y una
tabla que todavía no existen. El bootstrap se ejecuta con state local y su
archivo `terraform.tfstate` **se commitea al repo** — no contiene secretos
(solo nombres y ARNs del bucket y la tabla) y garantiza que el propio
bootstrap sea reproducible desde cero.

Esto NO aplica al stack principal (`terraform/environments/dev/`), que sí usa
backend `s3` apuntando al bucket creado aquí.

## Uso

```
cd terraform/bootstrap
terraform init
terraform apply
```

Los `.tf` de este directorio se crean en la Fase 1.
