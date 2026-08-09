import { QueryClient } from "@tanstack/react-query";

export function getContext() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: import.meta.env.PROD ? 3 : false,
        refetchOnMount: true,
        refetchOnReconnect: true,
        refetchOnWindowFocus: true,
      },
      mutations: {
        retry: import.meta.env.PROD ? 3 : false,
      },
    },
  });

  return {
    queryClient,
  };
}
