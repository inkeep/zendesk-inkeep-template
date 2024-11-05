import type { ReactElement } from 'react';
import styles from "./page.module.css";

export default function Home(): ReactElement {
  return (
    <div className={styles.page}>
      <main className={styles.main}>
        <h1>Server Environment</h1>
        <p>This instance is running as a server only.</p>
      </main>
    </div>
  );
}
