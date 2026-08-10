import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/restaurants/$restaurantId")({
  component: Page,
});

function Page() {
  const { restaurantId } = Route.useParams();

  return <div>Hello "/restaurants/{restaurantId}"!</div>;
}
