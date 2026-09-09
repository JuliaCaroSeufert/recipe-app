// Metro/Expo handle CSS imports; keep TypeScript quiet about them.
declare module '*.css';
declare module '*.module.css' {
  const classes: { readonly [key: string]: string };
  export default classes;
}
