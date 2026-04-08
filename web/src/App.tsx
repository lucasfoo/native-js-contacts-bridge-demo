import { HashRouter, Routes, Route, Link, useLocation, useNavigate } from 'react-router'
import ContactsPage from './ContactsPage'
import ContactDetailPage from './ContactDetailPage'
import StressTestControls from './StressTestControls'
import OptimizedContactsPage from './OptimizedContactsPage'

function Navbar() {
  const location = useLocation()
  const navigate = useNavigate()
  const isHome = location.pathname === '/'

  return (
    <nav className="navbar">
      {isHome ? (
        <div className="navbar-back" />
      ) : (
        <button className="navbar-back" onClick={() => navigate(-1)}>
          ‹ Back
        </button>
      )}
      <span className="navbar-title">Native Bridge Demo</span>
      <div className="navbar-back" />
    </nav>
  )
}

function Home() {
  return (
    <div style={{ padding: 20 }}>
      <Link to="/contacts" style={{ color: '#007aff', fontSize: 18, display: 'block', marginBottom: 24 }}>
        View Contacts →
      </Link>
      <Link to="/contacts-optimized" style={{ color: '#007aff', fontSize: 18, display: 'block', marginBottom: 24 }}>
        View Contacts (Optimized) →
      </Link>
      <StressTestControls />
    </div>
  )
}

function App() {
  return (
    <HashRouter>
      <Navbar />
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/contacts" element={<ContactsPage />} />
        <Route path="/contacts/:index" element={<ContactDetailPage />} />
        <Route path="/contacts-optimized" element={<OptimizedContactsPage />} />
        <Route path="/contacts-optimized/:index" element={<ContactDetailPage />} />
      </Routes>
    </HashRouter>
  )
}

export default App
