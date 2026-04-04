import { useLocation, useNavigate } from 'react-router'
import type { Contact } from './bridge'
import './ContactsPage.css'

function ContactDetailPage() {
  const location = useLocation()
  const navigate = useNavigate()
  const contact = location.state?.contact as Contact | undefined

  if (!contact) {
    return (
      <div className="container">
        <p>Contact not found.</p>
        <button onClick={() => navigate('/contacts')}>Back to contacts</button>
      </div>
    )
  }

  return (
    <div className="container detail-page">
      <div className="detail-avatar">
        {(contact.givenName[0] || '') + (contact.familyName[0] || '')}
      </div>
      <h1 className="detail-name">{contact.givenName} {contact.familyName}</h1>
      {contact.phoneNumbers.length > 0 && (
        <div className="detail-phones">
          {contact.phoneNumbers.map((p, i) => (
            <div key={i} className="detail-phone">
              <span className="detail-phone-label">phone</span>
              <a href={`tel:${p}`} className="detail-phone-number">{p}</a>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default ContactDetailPage
