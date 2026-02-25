import { useEffect } from 'react'
import { instance } from './MdocDataTransfer'

export const useMdocDataTransferShutdownOnUnmount = () =>
  useEffect(() => {
    return () => {
      if (instance) instance.shutdown()
    }
  }, [])
