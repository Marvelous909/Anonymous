export const theme = {
  colors: {
    primary: {
      dark: '#173300',    // Mørkegrønn
      light: '#C8FC3C',   // Lysegrønn
    },
    background: {
      light: '#ffffff',
      dark: '#1a1a1a',
      subtle: '#f5f5f5',
    },
    text: {
      primary: '#1a1a1a',
      secondary: '#666666',
      inverse: '#ffffff',
    },
    border: {
      light: '#e5e5e5',
      dark: '#333333',
    }
  },
  spacing: {
    xs: '0.25rem',
    sm: '0.5rem',
    md: '1rem',
    lg: '1.5rem',
    xl: '2rem',
  },
  borderRadius: {
    sm: '2px',
    md: '4px',
    lg: '8px',
  }
} as const;