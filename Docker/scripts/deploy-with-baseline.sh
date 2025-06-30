#!/bin/bash
set -e

PROVIDER=${DATABASE_PROVIDER:-postgresql}
SCHEMA_FILE="./prisma/${PROVIDER}-schema.prisma"
MIGRATIONS_DIR="./prisma/migrations"
BASELINE_DIR="${MIGRATIONS_DIR}/0_baseline"

echo "🚀 Starting deployment for provider: $PROVIDER"

# Limpiar y copiar migraciones
echo "📂 Setting up migrations..."
rm -rf "$MIGRATIONS_DIR"
cp -r "./prisma/${PROVIDER}-migrations" "$MIGRATIONS_DIR"

# Función para crear baseline
create_baseline() {
    echo "📋 Creating baseline migration..."
    mkdir -p "$BASELINE_DIR"
    
    npx prisma migrate diff \
        --from-empty \
        --to-schema-datamodel "$SCHEMA_FILE" \
        --script > "${BASELINE_DIR}/migration.sql"
    
    echo "✅ Baseline migration created"
    
    # Marcar baseline como aplicado
    npx prisma migrate resolve --applied 0_baseline --schema "$SCHEMA_FILE"
    echo "✅ Baseline marked as applied"
}

# Intentar deploy
echo "🔄 Attempting migration deploy..."
if ! npx prisma migrate deploy --schema "$SCHEMA_FILE" 2>&1; then
    DEPLOY_EXIT_CODE=$?
    
    # Capturar output del error
    DEPLOY_OUTPUT=$(npx prisma migrate deploy --schema "$SCHEMA_FILE" 2>&1 || true)
    
    if echo "$DEPLOY_OUTPUT" | grep -q "P3005"; then
        echo "⚠️  P3005 Error detected: Database schema is not empty"
        create_baseline
        
        echo "🔄 Retrying migration deploy after baseline..."
        npx prisma migrate deploy --schema "$SCHEMA_FILE"
        echo "✅ Migration deploy successful after baseline"
    else
        echo "❌ Other migration error occurred:"
        echo "$DEPLOY_OUTPUT"
        exit $DEPLOY_EXIT_CODE
    fi
else
    echo "✅ Migration deploy successful"
fi

echo "🎉 Deployment completed successfully"