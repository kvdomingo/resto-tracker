import { LngLat } from "maplibre-gl";
import type { Bbox } from "@/types/map";

export const INITIAL_ZOOM = 10.5;

export const INITIAL_CENTER = new LngLat(121.04, 14.56);

export const INITIAL_BBOX: Bbox = {
  n: 14.75926,
  e: 121.24068,
  w: 120.79836,
  s: 14.33112,
};
