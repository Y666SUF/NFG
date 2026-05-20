import { Component } from "react";

export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error, info) {
    console.error("[hangman] UI error", error, info);
  }

  render() {
    if (this.state.error) {
      return (
        <main className="app-shell">
          <section className="panel">
            <h2>Something went wrong</h2>
            <p className="error">{String(this.state.error?.message || this.state.error)}</p>
            <button
              type="button"
              className="tab active"
              style={{ marginTop: "0.75rem" }}
              onClick={() => {
                this.setState({ error: null });
                window.location.reload();
              }}
            >
              Reload app
            </button>
          </section>
        </main>
      );
    }
    return this.props.children;
  }
}
