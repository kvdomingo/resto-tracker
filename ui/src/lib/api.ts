import createFetchClient from "openapi-fetch";
import createClient from "openapi-react-query";
import type { components, paths } from "@/types/generated";

const fetchClient = createFetchClient<paths>({
  credentials: "include",
});
export const $api = createClient(fetchClient);

export const PAGINATED_SENTINEL: {
  data: never[];
  meta: components["schemas"]["PaginatedMeta"];
} = {
  data: [],
  meta: {
    page: 1,
    page_count: 10,
    page_size: 0,
    total_count: null,
  },
} as const;
