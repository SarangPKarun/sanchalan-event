import { NavLink } from "react-router-dom";

export function CategoriesNav({ pending }: { pending?: number | undefined }) {
  const cls = ({ isActive }: { isActive: boolean }) => (isActive ? "tab tab-active" : "tab");
  return (
    <nav className="tabs" aria-label="Categories sections">
      <NavLink to="/categories" end className={cls}>
        All categories
      </NavLink>
      <NavLink to="/categories/proposals" className={cls}>
        Proposals{pending ? <span className="tab-count">{pending}</span> : null}
      </NavLink>
    </nav>
  );
}
