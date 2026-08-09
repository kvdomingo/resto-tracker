import { createFileRoute, Link } from "@tanstack/react-router";
import { MapPin } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Map as MapComponent, MapMarker, MarkerContent } from "@/components/ui/map.tsx";
import { Skeleton } from "@/components/ui/skeleton";
import { useRootQueryStates } from "@/hooks/use-root-query-states.ts";
import { $api, PAGINATED_SENTINEL } from "@/lib/api.ts";
import { INITIAL_CENTER, INITIAL_ZOOM } from "@/lib/constants.ts";

export const Route = createFileRoute("/")({
  component: Page,
});

function Page() {
  const [{ page, page_size }] = useRootQueryStates();

  const { data = PAGINATED_SENTINEL, isLoading } = $api.useQuery(
    "get",
    "/api/restaurants",
    {
      params: {
        query: { page, page_size },
      },
    },
  );

  return (
    <div className="p-8 flex flex-col gap-4">
      <h1 className="text-4xl font-bold">Welcome to TanStack Start</h1>
      <div className="grid grid-cols-2 gap-4">
        <div className="grid grid-cols-2 gap-2">
          {isLoading
            ? Array.from({ length: 6 })
                .fill(0)
                .map((_, i) => <Skeleton key={i} className="aspect-video" />)
            : data.data.map((item) => (
                <Link
                  key={item.id}
                  to={`/restaurants/${item.id}`}
                  className="aspect-video hover:scale-[101%] transition-transform duration-100"
                >
                  <Card className="size-full">
                    <CardHeader>
                      <CardTitle>{item.name}</CardTitle>
                    </CardHeader>
                    <CardContent>
                      {item.branches.map((branch) => branch.location).join("\n")}
                    </CardContent>
                  </Card>
                </Link>
              ))}
        </div>
        <Card className="aspect-square p-0">
          <CardContent className="size-full p-0">
            <MapComponent
              center={INITIAL_CENTER}
              zoom={INITIAL_ZOOM}
              className="size-full overflow-hidden rounded-lg"
            >
              {data.data.map((resto) => (
                <MapMarker
                  key={resto.id}
                  longitude={resto.branches.at(0)!.geography!.longitude}
                  latitude={resto.branches.at(0)!.geography!.latitude}
                >
                  <MarkerContent>
                    <MapPin size={36} className="fill-primary" fillOpacity={100} />
                  </MarkerContent>
                </MapMarker>
              ))}
            </MapComponent>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
