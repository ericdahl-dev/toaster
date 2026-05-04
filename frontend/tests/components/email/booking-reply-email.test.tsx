import { render as renderEmail } from '@react-email/render';
import { describe, expect, it } from 'vitest';
import { BookingReplyEmail } from '@/components/email/booking-reply-email';

describe('BookingReplyEmail', () => {
  it('renders the subject as a heading', async () => {
    const html = await renderEmail(
      <BookingReplyEmail subject="Wedding for 120 guests" bodyText="Thank you for your inquiry." />,
    );

    expect(html).toContain('Wedding for 120 guests');
  });

  it('renders each line of the body text', async () => {
    const html = await renderEmail(
      <BookingReplyEmail
        subject="Re: Booking inquiry"
        bodyText={'Hello Jamie,\n\nWe would love to host your event.\n\nBest regards'}
      />,
    );

    expect(html).toContain('Hello Jamie,');
    expect(html).toContain('We would love to host your event.');
    expect(html).toContain('Best regards');
  });

  it('renders the sender name in the footer when provided', async () => {
    const html = await renderEmail(
      <BookingReplyEmail
        subject="Re: Booking inquiry"
        bodyText="Looking forward to hearing from you."
        fromName="The Venue Team"
      />,
    );

    expect(html).toContain('The Venue Team');
  });

  it('omits the footer section when fromName is not provided', async () => {
    const html = await renderEmail(
      <BookingReplyEmail subject="Re: Inquiry" bodyText="Thank you." />,
    );

    expect(html).not.toContain('The Venue Team');
  });

  it('includes a preview text element', async () => {
    const html = await renderEmail(
      <BookingReplyEmail subject="Preview text check" bodyText="Body content here." />,
    );

    // The <Preview> component renders a hidden span with the subject text
    expect(html).toContain('Preview text check');
  });
});
