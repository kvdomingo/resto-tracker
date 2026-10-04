import { useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { useMap } from "./ui/map";

export function MapInit() {
  const navigate = useNavigate({ from: "/" });
  const { map, isLoaded } = useMap();

  useEffect(() => {
    if (!map || !isLoaded) return;

    const update = () => {
      const b = map.getBounds();
      navigate({
        to: "/",
        search: {
          bbox: {
            n: parseFloat(b.getNorth().toFixed(5)),
            e: parseFloat(b.getEast().toFixed(5)),
            w: parseFloat(b.getWest().toFixed(5)),
            s: parseFloat(b.getSouth().toFixed(5)),
          },
        },
        replace: true,
      });
    };

    map.on("load", update);
    map.on("moveend", update);

    return () => {
      map.off("moveend", update);
    };
  }, [map, isLoaded, navigate]);

  return null;
}
