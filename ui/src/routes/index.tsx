import { createFileRoute, Link } from "@tanstack/react-router";
import { UtensilsIcon } from "lucide-react";
import { useState } from "react";
import z from "zod";
import { MapInit } from "@/components/map-init";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Map as MapComponent, MapMarker, MarkerContent } from "@/components/ui/map.tsx";
import { Rating } from "@/components/ui/rating";
import { Skeleton } from "@/components/ui/skeleton";
import { env } from "@/env";
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
        query: { page, page_size },
      },
    },
  );

  return (
    <div className="p-8 flex flex-col gap-4">
      <h1 className="text-4xl font-bold">
        {isLoading ? "Loading..." : `Found ${data.meta.page_count} restaurants`}
      </h1>
      {env.DEV && (
        <div className="flex flex-col">
          <span>
            bounds:{" "}
            {`${bbox.n.toFixed(5)}, ${bbox.e.toFixed(5)}, ${bbox.w.toFixed(5)}, ${bbox.s.toFixed(5)}`}
          </span>
        </div>
      )}
      <div className="grid grid-cols-2 gap-8">
        <div className="grid grid-cols-2 gap-2">
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
                            <li key={branch.location}>{branch.location}</li>
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
            >
              <MapInit />

              {data.data.map((resto) => (
                <MapMarker
                  key={resto.id}
                  longitude={resto.branches.at(0)!.geography!.longitude}
                  latitude={resto.branches.at(0)!.geography!.latitude}
                >
                  <MarkerContent>
                    <UtensilsIcon
                      size={36}
                      className={cn("fill-primary transition-transform duration-150", {
                        "scale-110": hoveredResto === resto.id,
                      })}
                      fillOpacity={100}
                      onMouseEnter={() => setHoveredResto(resto.id)}
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
