import { defineConfig } from '@wagmi/cli'
import contractSpec from './wagmi/auto'
import { react,ReactConfig } from '@wagmi/cli/plugins'

 const reactConfig:ReactConfig = {
  
 }

export default defineConfig({
  out: '../reflax-ui/src/hooks/contract/reflax.ts',
  contracts: contractSpec,
  plugins: [
    react(),
  ],
})
