import {
  Body,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Preview,
  Section,
  Text,
} from '@react-email/components';

export type BookingReplyEmailProps = {
  subject: string;
  bodyText: string;
  fromName?: string | null;
};

export function BookingReplyEmail({ subject, bodyText, fromName }: BookingReplyEmailProps) {
  return (
    <Html lang="en">
      <Head />
      <Preview>{subject}</Preview>
      <Body style={bodyStyle}>
        <Container style={containerStyle}>
          <Section style={headerStyle}>
            <Heading style={headingStyle}>{subject}</Heading>
          </Section>

          <Hr style={hrStyle} />

          <Section style={contentStyle}>
            {bodyText.split('\n').map((line, index) => (
              <Text key={index} style={textStyle}>
                {line || '\u00A0'}
              </Text>
            ))}
          </Section>

          {fromName && (
            <>
              <Hr style={hrStyle} />
              <Section style={footerStyle}>
                <Text style={footerTextStyle}>{fromName}</Text>
              </Section>
            </>
          )}
        </Container>
      </Body>
    </Html>
  );
}

const bodyStyle: React.CSSProperties = {
  backgroundColor: '#f4f4f5',
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  margin: '0',
  padding: '40px 0',
};

const containerStyle: React.CSSProperties = {
  backgroundColor: '#ffffff',
  borderRadius: '12px',
  margin: '0 auto',
  maxWidth: '600px',
  padding: '0',
};

const headerStyle: React.CSSProperties = {
  padding: '28px 32px 20px',
};

const headingStyle: React.CSSProperties = {
  color: '#09090b',
  fontSize: '20px',
  fontWeight: '600',
  lineHeight: '1.4',
  margin: '0',
};

const hrStyle: React.CSSProperties = {
  borderColor: '#e4e4e7',
  margin: '0',
};

const contentStyle: React.CSSProperties = {
  padding: '24px 32px',
};

const textStyle: React.CSSProperties = {
  color: '#3f3f46',
  fontSize: '15px',
  lineHeight: '1.7',
  margin: '0 0 4px',
};

const footerStyle: React.CSSProperties = {
  padding: '16px 32px 24px',
};

const footerTextStyle: React.CSSProperties = {
  color: '#71717a',
  fontSize: '13px',
  margin: '0',
};
