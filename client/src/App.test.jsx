import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import App from "./App";
import { AuthProviderWrapper } from "./context/auth.context";

test("renders the navbar for an anonymous visitor", () => {
  render(
    <MemoryRouter>
      <AuthProviderWrapper>
        <App />
      </AuthProviderWrapper>
    </MemoryRouter>
  );

  expect(screen.getByAltText(/restauranty/i)).toBeInTheDocument();
  expect(screen.getByText(/welcome to restauranty/i)).toBeInTheDocument();
});
