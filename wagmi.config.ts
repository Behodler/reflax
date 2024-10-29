import { defineConfig } from '@wagmi/cli'
import contractSpec from './wagmi/auto'
import { react } from '@wagmi/cli/plugins'

export default defineConfig({
  out: '../reflax-ui/src/hooks/contract/reflax.ts',
  contracts: contractSpec,
  plugins: [
    react(),
  ],
})
