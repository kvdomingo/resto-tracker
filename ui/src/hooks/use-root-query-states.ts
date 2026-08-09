import { parseAsInteger, useQueryStates } from "nuqs";

export function useRootQueryStates() {
  return useQueryStates({
    page: parseAsInteger.withDefault(1),
    page_size: parseAsInteger.withDefault(10),
  });
}
