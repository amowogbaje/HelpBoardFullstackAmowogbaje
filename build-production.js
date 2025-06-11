import { build } from 'vite';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function buildProduction() {
  try {
    // Build the client
    await build({
      root: path.join(__dirname, 'client'),
      build: {
        outDir: path.join(__dirname, 'dist/client'),
        emptyOutDir: true,
        rollupOptions: {
          input: path.join(__dirname, 'client/index.html')
        }
      }
    });
    
    console.log('✅ Client build completed');
  } catch (error) {
    console.error('❌ Build failed:', error);
    process.exit(1);
  }
}

buildProduction();