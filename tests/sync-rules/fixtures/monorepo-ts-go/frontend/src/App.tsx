import React from 'react';

interface AppProps {
  title: string;
}

const App: React.FC<AppProps> = ({ title }) => {
  return <div className="app">{title}</div>;
};

export default App;
