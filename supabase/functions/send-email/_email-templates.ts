export var EmailAction;
(function(EmailAction) {
  EmailAction["WELCOME"] = "WELCOME";
})(EmailAction || (EmailAction = {}));
export const BASE_TEMPLATE = (content)=>`
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html dir="ltr" lang="en">
  <head>
    <meta name="viewport" content="width=device-width" />
    <link
      rel="preload"
      as="image"
      href="https://shoreline.islandshq.xyz/lovable-uploads/68cc7aba-b33c-4af4-be9b-8eb2d095b48b.png"
    />
    <link
      rel="preload"
      as="image"
      href="https://cdn.loom.com/sessions/thumbnails/e699ea83a4c04d738a8e2b48bb286ee6-e4c66277e210fe1d-full-play.gif"
    />
    <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
    <meta name="x-apple-disable-message-reformatting" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="x-apple-disable-message-reformatting" />
    <meta
      name="format-detection"
      content="telephone=no,address=no,email=no,date=no,url=no"
    />
    <meta name="color-scheme" content="light" />
    <meta name="supported-color-schemes" content="light" />
    <!--$-->
    <style>
      @font-face {
        font-family: "Inter";
        font-style: normal;
        font-weight: 400;
        mso-font-alt: "sans-serif";
        src: url(https://rsms.me/inter/font-files/Inter-Regular.woff2?v=3.19)
          format("woff2");
      }

      * {
        font-family: "Inter", sans-serif;
      }
    </style>
    <style>
      blockquote,
      h1,
      h2,
      h3,
      img,
      li,
      ol,
      p,
      ul {
        margin-top: 0;
        margin-bottom: 0;
      }
      @media only screen and (max-width: 425px) {
        .tab-row-full {
          width: 100% !important;
        }
        .tab-col-full {
          display: block !important;
          width: 100% !important;
        }
        .tab-pad {
          padding: 0 !important;
        }
      }
    </style>
  </head>
  <body style="margin: 0">
    <table
      align="center"
      width="100%"
      border="0"
      cellpadding="0"
      cellspacing="0"
      role="presentation"
      style="
        max-width: 600px;
        min-width: 300px;
        width: 100%;
        margin-left: auto;
        margin-right: auto;
        padding: 0.5rem;
      "
    >
      <tbody>
        <tr style="width: 100%">
          <td>
            <table
              align="center"
              width="100%"
              border="0"
              cellpadding="0"
              cellspacing="0"
              role="presentation"
              style="margin-top: 0px; margin-bottom: 32px"
            >
              <tbody style="width: 100%">
                <tr style="width: 100%">
                  <td align="center" data-id="__react-email-column">
                    <img
                      title="Image"
                      alt="Image"
                      src="https://shoreline.islandshq.xyz/lovable-uploads/68cc7aba-b33c-4af4-be9b-8eb2d095b48b.png"
                      style="
                        display: block;
                        outline: none;
                        border: none;
                        text-decoration: none;
                        width: 150px;
                        max-width: 100%;
                        border-radius: 8px;
                      "
                    />
                  </td>
                </tr>
              </tbody>
            </table>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: #080808">${content}</span>
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: #080808"
                >Great news - you&#x27;ve just unlocked the secret to </span
              ><span style="color: #080808"
                ><strong>hiring amazing Canadian talent</strong></span
              ><span style="color: #080808">
                without all the legal complexities! Welcome to Shoreline,
                Canada&#x27;s #1 Employer of Record.</span
              >
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: #080808"
                >I&#x27;m Ali, Founder and CEO, and I&#x27;m thrilled
                you&#x27;ve joined us. We created Shoreline because we saw too
                many brilliant companies missing out on Canadian tech superstars
                (and those sweet government grants!) just because of complex
                legal requirements.</span
              >
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
               
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: #080808">What can Shoreline do for you?</span>
            </p>
            <table
              align="center"
              width="100%"
              border="0"
              cellpadding="0"
              cellspacing="0"
              role="presentation"
              style="max-width: 100%"
            >
              <tbody>
                <tr style="width: 100%">
                  <td>
                    <ul
                      style="
                        margin-top: 0px;
                        margin-bottom: 20px;
                        padding-left: 26px;
                        list-style-type: disc;
                      "
                    >
                      <li
                        style="
                          margin-bottom: 8px;
                          padding-left: 6px;
                          -webkit-font-smoothing: antialiased;
                          -moz-osx-font-smoothing: grayscale;
                        "
                      >
                        <p
                          style="
                            font-size: 15px;
                            line-height: 26.25px;
                            margin: 0 0 0px 0;
                            -webkit-font-smoothing: antialiased;
                            -moz-osx-font-smoothing: grayscale;
                            color: #374151;
                          "
                        >
                          <span style="color: #080808"
                            ><strong>Hire top Canadian talent</strong></span
                          ><span style="color: #080808">
                            without establishing a legal entity</span
                          >
                        </p>
                      </li>
                      <li
                        style="
                          margin-bottom: 8px;
                          padding-left: 6px;
                          -webkit-font-smoothing: antialiased;
                          -moz-osx-font-smoothing: grayscale;
                        "
                      >
                        <p
                          style="
                            font-size: 15px;
                            line-height: 26.25px;
                            margin: 0 0 0px 0;
                            -webkit-font-smoothing: antialiased;
                            -moz-osx-font-smoothing: grayscale;
                            color: #374151;
                          "
                        >
                          <span style="color: #080808"
                            ><strong
                              >Save up to 50% on total costs</strong
                            ></span
                          ><span style="color: #080808">
                            compared to local hiring</span
                          >
                        </p>
                      </li>
                      <li
                        style="
                          margin-bottom: 8px;
                          padding-left: 6px;
                          -webkit-font-smoothing: antialiased;
                          -moz-osx-font-smoothing: grayscale;
                        "
                      >
                        <p
                          style="
                            font-size: 15px;
                            line-height: 26.25px;
                            margin: 0 0 0px 0;
                            -webkit-font-smoothing: antialiased;
                            -moz-osx-font-smoothing: grayscale;
                            color: #374151;
                          "
                        >
                          <span style="color: #080808"
                            ><strong>Access Canadian grants</strong></span
                          ><span style="color: #080808">
                            (our clients are already cashing in!)</span
                          >
                        </p>
                      </li>
                      <li
                        style="
                          margin-bottom: 8px;
                          padding-left: 6px;
                          -webkit-font-smoothing: antialiased;
                          -moz-osx-font-smoothing: grayscale;
                        "
                      >
                        <p
                          style="
                            font-size: 15px;
                            line-height: 26.25px;
                            margin: 0 0 0px 0;
                            -webkit-font-smoothing: antialiased;
                            -moz-osx-font-smoothing: grayscale;
                            color: #374151;
                          "
                        >
                          <span style="color: #080808"
                            ><strong
                              >Simplify Canadian payroll, benefits, and
                              compliance</strong
                            ></span
                          ><span style="color: #080808">
                            without owning a legal entity</span
                          >
                        </p>
                      </li>
                      <li
                        style="
                          margin-bottom: 8px;
                          padding-left: 6px;
                          -webkit-font-smoothing: antialiased;
                          -moz-osx-font-smoothing: grayscale;
                        "
                      >
                        <p
                          style="
                            font-size: 15px;
                            line-height: 26.25px;
                            margin: 0 0 0px 0;
                            -webkit-font-smoothing: antialiased;
                            -moz-osx-font-smoothing: grayscale;
                            color: #374151;
                          "
                        >
                          <span style="color: #080808"
                            ><strong
                              >Full recruiting services available</strong
                            ></span
                          ><span style="color: #080808">
                            - don&#x27;t have your candidate yet? We&#x27;ll
                            source, screen, and find the perfect candidate so
                            you don&#x27;t have to</span
                          >
                        </p>
                      </li>
                    </ul>
                  </td>
                </tr>
              </tbody>
            </table>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
               
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: #080808"
                >Your account is ready and waiting for you! </span
              ><a
                href="https://shoreline.islandshq.xyz/"
                rel="noopener noreferrer"
                style="color: #111827; text-decoration: none; font-weight: 500"
                target="_blank"
                ><span style="color: #6127f0"
                  ><strong>Login here</strong></span
                ></a
              ><span style="color: #080808"> whenever you need us. </span>
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <a
                href="https://shoreline.islandshq.xyz/lovable-uploads/68cc7aba-b33c-4af4-be9b-8eb2d095b48b.png"
                rel="noopener noreferrer nofollow"
                style="color: #111827; text-decoration: none; font-weight: 500"
                target="_blank"
                ><span style="color: #080808"
                  ><strong
                    >Ready to make your first Canadian hire?</strong
                  ></span
                ></a
              ><br /><span style="color: #080808"
                >Let&#x27;s get started! Book a 30-minute call with one of our
                Shoreline Consultants who will walk you through everything you
                need to know:</span
              >
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: rgb(8, 8, 8)">Follow this link: </span
              ><a
                href="https://calendly.com/islands-growth/shoreline"
                rel="noopener noreferrer nofollow"
                style="color: #111827; text-decoration: none; font-weight: 500"
                target="_blank"
                ><span style="color: rgb(97, 39, 240)"
                  ><strong
                    >https://calendly.com/islands-growth/shoreline</strong
                  ></span
                ></a
              >
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: #080808"
                >Can&#x27;t wait to see who you&#x27;ll bring on board!</span
              >
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
               
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <a
                href="https://calendly.com/islands-growth/shorelineNeed"
                rel="noopener noreferrer nofollow"
                style="color: #111827; text-decoration: none; font-weight: 500"
                target="_blank"
                ><span style="color: #080808"><strong>Need</strong></span></a
              ><span style="color: #080808"> more info? Watch </span
              ><a
                href="https://www.loom.com/share/e699ea83a4c04d738a8e2b48bb286ee6?sid=c7265074-7197-4c05-a2bf-5facebef3d02"
                rel="noopener noreferrer"
                style="color: #111827; text-decoration: none; font-weight: 500"
                target="_blank"
                ><span style="color: #6127f0"
                  ><strong>this video</strong></span
                ></a
              ><span style="color: #080808"> to get started.</span>
            </p>
            <table
              align="center"
              width="100%"
              border="0"
              cellpadding="0"
              cellspacing="0"
              role="presentation"
              style="margin-top: 0px; margin-bottom: 32px"
            >
              <tbody style="width: 100%">
                <tr style="width: 100%">
                  <td align="center" data-id="__react-email-column">
                    <a
                      href="https://www.loom.com/share/e699ea83a4c04d738a8e2b48bb286ee6"
                      rel="noopener noreferrer"
                      style="
                        display: block;
                        max-width: 100%;
                        text-decoration: none;
                      "
                      target="_blank"
                      ><img
                        title="Image"
                        alt="Image"
                        src="https://cdn.loom.com/sessions/thumbnails/e699ea83a4c04d738a8e2b48bb286ee6-e4c66277e210fe1d-full-play.gif"
                        style="
                          display: block;
                          outline: none;
                          border: none;
                          text-decoration: none;
                          width: 600px;
                          max-width: 100%;
                          border-radius: 0;
                        "
                    /></a>
                  </td>
                </tr>
              </tbody>
            </table>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
               
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: #080808">Cheers,</span>
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: #080808"><strong>Ali</strong></span
              ><br /><span style="color: #080808">Founder &amp; CEO</span
              ><br /><a
                href="https://www.islandshq.xyz/shoreline-eor"
                rel="noopener noreferrer"
                style="
                  color: #111827;
                  text-decoration-line: none;
                  font-weight: 500;
                  text-decoration: none;
                "
                target="_blank"
                ><span style="color: #080808"
                  ><em><strong>Shoreline</strong></em></span
                ></a
              ><span style="color: #080808">, an Island X venture</span>
            </p>
            <p
              style="
                font-size: 15px;
                line-height: 26.25px;
                margin: 0 0 20px 0;
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
                color: #374151;
              "
            >
              <span style="color: #080808"
                ><em
                  >P.S. Have questions? Just hit reply - my team and I are here
                  to help!</em
                ></span
              >
            </p>
          </td>
        </tr>
      </tbody>
    </table>
    <!--/$-->
  </body>
</html>
`;
export const actionTemplates = {
  [EmailAction.WELCOME]: {
    subject: "🇨🇦 Welcome to Shoreline - Unlock Canadian Tech Talent Without the Headaches!",
    template: (vars)=>BASE_TEMPLATE(`
        Hey ${vars.name}! You&#x27;re
                in!
      `)
  }
};
