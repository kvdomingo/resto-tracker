import { keepPreviousData } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { UtensilsIcon } from "lucide-react";
import { useState } from "react";
import z from "zod";
import { MapInit } from "@/components/map-init";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Map as MapComponent, MapMarker, MarkerContent } from "@/components/ui/map.tsx";
import { Rating } from "@/components/ui/rating";
import { Skeleton } from "@/components/ui/skeleton";
import { useRootQueryStates } from "@/hooks/use-root-query-states.ts";
import { $api, PAGINATED_SENTINEL } from "@/lib/api.ts";
import { INITIAL_BBOX } from "@/lib/constants.ts";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/")({
  component: Page,
  validateSearch: z.object({
    bbox: z
      .object({
        n: z.number().min(-90).max(90),
        e: z.number().min(-180).max(180),
        w: z.number().min(-180).max(180),
        s: z.number().min(-90).max(90),
      })
      .catch({
        n: INITIAL_BBOX.n,
        e: INITIAL_BBOX.e,
        w: INITIAL_BBOX.w,
        s: INITIAL_BBOX.s,
      }),
  }),
});

function Page() {
  const [{ page, page_size }] = useRootQueryStates();
  const { bbox } = Route.useSearch();
  const [hoveredResto, setHoveredResto] = useState<string | null>(null);

  const { data = PAGINATED_SENTINEL, isLoading } = $api.useQuery(
    "get",
    "/api/restaurants",
    {
      params: {
        query: { page, page_size, ...bbox },
      },
    },
    {
      placeholderData: keepPreviousData,
    },
  );

  return (
    <div className="p-8 flex flex-col gap-4">
      <h1 className="text-4xl font-bold">
        {isLoading ? "Loading..." : `Found ${data.meta.page_count} restaurants`}
      </h1>
      <div className="grid grid-cols-2 gap-8">
        <div className="grid grid-cols-2 gap-4">
          {isLoading
            ? Array.from({ length: 6 })
                .fill(0)
                .map((_, i) => <Skeleton key={i} className="aspect-video" />)
            : data.data.map((item) => (
                <Link
                  key={item.id}
                  to="/restaurants/$restaurantId"
                  params={{ restaurantId: item.id }}
                  className="aspect-video"
                >
                  <Card
                    className={cn(
                      "size-full hover:scale-[101%] transition-transform duration-150",
                      {
                        "scale-[101%]": hoveredResto === item.id,
                      },
                    )}
                    onMouseEnter={() => setHoveredResto(item.id)}
                    onMouseLeave={() => setHoveredResto(null)}
                  >
                    <CardHeader>
                      <CardTitle className="text-2xl">{item.name}</CardTitle>
                    </CardHeader>
                    <CardContent className="flex flex-col gap-2">
                      <div>
                        <b>Branches</b>
                        <ul>
                          {item.branches.map((branch) => (
                            <li key={branch.id}>{branch.label}</li>
                          ))}
                        </ul>
                      </div>
                      <Rating readOnly />
                    </CardContent>
                  </Card>
                </Link>
              ))}
        </div>

        <Card className="aspect-square p-0">
          <CardContent className="size-full p-0">
            <MapComponent
              bounds={[bbox.w, bbox.s, bbox.e, bbox.n]}
              className="size-full overflow-hidden rounded-lg"
              theme="light"
            >
              <MapInit />

              {data.data
                .flatMap((d) => d.branches)
                .map((branch) => (
                  <MapMarker
                    key={branch.id}
                    longitude={branch.geography.longitude}
                    latitude={branch.geography.latitude}
                  >
                    <MarkerContent>
                      <UtensilsIcon
                        size={36}
                        className={cn(
                          "fill-primary transition-transform duration-150",
                          {
                            "scale-110": hoveredResto === branch.restaurant_id,
                          },
                        )}
                        fillOpacity={100}
                        onMouseEnter={() => setHoveredResto(branch.restaurant_id)}
                        onMouseLeave={() => setHoveredResto(null)}
                      />
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
