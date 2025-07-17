#!/bin/bash

# Script to remove print statements and log statements from Android Kotlin files

echo "Cleaning log statements from Android Kotlin files..."

# Function to clean a file
clean_file() {
    local file="$1"
    echo "Cleaning: $file"
    
    # Create backup
    cp "$file" "$file.backup"
    
    # Remove print statements
    sed -i '' '/print(/d' "$file"
    
    # Remove Log.d statements
    sed -i '' '/Log\.d(/d' "$file"
    
    # Remove Log.e statements
    sed -i '' '/Log\.e(/d' "$file"
    
    # Remove Log.i statements
    sed -i '' '/Log\.i(/d' "$file"
    
    # Remove Log.v statements
    sed -i '' '/Log\.v(/d' "$file"
    
    # Remove Log.w statements
    sed -i '' '/Log\.w(/d' "$file"
    
    # Remove Log.wtf statements
    sed -i '' '/Log\.wtf(/d' "$file"
    
    # Remove android.util.Log import if no other Log statements remain
    if ! grep -q "Log\." "$file"; then
        sed -i '' '/import android\.util\.Log/d' "$file"
    fi
    
    echo "Cleaned: $file"
}

# Clean PauseActivity.kt
if [ -f "android/app/src/main/kotlin/com/detach/app/PauseActivity.kt" ]; then
    clean_file "android/app/src/main/kotlin/com/detach/app/PauseActivity.kt"
else
    echo "Warning: PauseActivity.kt not found"
fi

# Clean AppLaunchInterceptor.kt
if [ -f "android/app/src/main/kotlin/com/detach/app/AppLaunchInterceptor.kt" ]; then
    clean_file "android/app/src/main/kotlin/com/detach/app/AppLaunchInterceptor.kt"
else
    echo "Warning: AppLaunchInterceptor.kt not found"
fi

echo "Log cleaning completed!"
echo "Backup files created with .backup extension" 