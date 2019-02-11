//
//  Mailchimp.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 19-11-2018.
//

import Foundation
import Networking

let mailchimp = Mailchimp()

struct Mailchimp {
    let base = URL(string: "https://us7.api.mailchimp.com/3.0/")!
    var apiKey = env.mailchimpApiKey
    var listId = env.mailchimpListId
    var authHeader: [String: String] { return ["Authorization": "Basic " + "anystring:\(apiKey)".base64Encoded] }
    
    struct CampaignSettings: Codable {
        var subject_line: String
        var title: String
        var from_name: String
        var reply_to: String
    }

    func createCampaign(for episode: Episode) -> RemoteEndpoint<String> {
        struct Response: Codable {
            var id: String
        }
        struct Create: Codable {
            struct Recipients: Codable {
                var list_id: String
            }
            var type: String
            var recipients: Recipients
            var settings: CampaignSettings
        }
        let url = base.appendingPathComponent("campaigns")
        let body = Create(
            type: "regular",
            recipients: .init(list_id: listId),
            settings: .init(
                subject_line: "New Swift Talk: \(episode.fullTitle)",
                title: campaignTitle(for: episode),
                from_name: "Swift Talk by objc.io",
                reply_to: "mail@objc.io"
            )
        )
        return RemoteEndpoint<Response>(json: .post, url: url, body: body, headers: authHeader).map { $0.id }
    }
    
    private func campaignTitle(for episode: Episode) -> String {
        return "Swift Talk #\(episode.number)"
    }
    
    func addContent(for episode: Episode, toCampaign campaignId: String) -> RemoteEndpoint<()> {
        struct Edit: Codable {
            var plain_text: String
            var html: String
        }
        let body = Edit(plain_text: plainText(episode), html: html(episode))
        let url = base.appendingPathComponent("campaigns/\(campaignId)/content")
        return RemoteEndpoint<()>(json: .put, url: url, body: body, headers: authHeader)
    }
    
    func testCampaign(campaignId: String) -> RemoteEndpoint<()> {
        struct Test: Codable {
            var test_emails: [String]
            var send_type: String
        }
        let url = base.appendingPathComponent("campaigns/\(campaignId)/actions/test")
        let body = Test(test_emails: ["mail@floriankugler.com"], send_type: "html")
        return RemoteEndpoint<()>(json: .post, url: url, body: body, headers: authHeader)
    }
    
    func sendCampaign(campaignId: String) -> RemoteEndpoint<()> {
        let url = base.appendingPathComponent("campaigns/\(campaignId)/actions/send")
        return RemoteEndpoint<()>(.post, url: url, headers: authHeader)
    }
    
    func existsCampaign(for episode: Episode) -> RemoteEndpoint<Bool> {
        struct Response: Codable {
            var campaigns: [Campaign]
        }
        struct Campaign: Codable {
            var settings: CampaignSettings
            var status: String
        }
        let url = base.appendingPathComponent("campaigns")
        let query: [String: String] = [
            "list_id": listId,
            "count": "10000",
            "since_create_time": DateFormatter.iso8601.string(from: episode.releaseAt)
        ]
        return RemoteEndpoint<Response>(json: .get, url: url, headers: authHeader, query: query).map { resp in
            return resp.campaigns.contains { $0.settings.title == self.campaignTitle(for: episode) }
        }
    }
}


private func plainText(_ episode: Episode) -> String {
    let url = env.baseURL.absoluteString + Route.episode(episode.id, .view(playPosition: nil)).path
    return """
    Dear Swift Talk Subscribers,
    
    We just published episode #\(episode.number): \(episode.fullTitle) (\(url))
    
    \(episode.synopsis)
    
    We hope you enjoy this new episode. Please send any questions and feedback our way!
    
    Best from Berlin,
    Chris & Florian
    
    ============================================================
    You are receiving this email because you opted in at our website https://talk.objc.io.
    
    Swift Talk is a project by objc.io
    
    Contact us at mail@objc.io (mailto:mail@objc.io) or on Twitter (@objcio)
    
    Our mailing address is: Kugler & Eidhof GbR • Paulsenstraße 26 • 12163 Berlin • Germany
    
    ** Unsubscribe from this list (*|UNSUB|*)
    ** Update subscription preferences (*|UPDATE_PROFILE|*)
    """
}

private func html(_ episode: Episode) -> String {
    let url = env.baseURL.absoluteString + Route.episode(episode.id, .view(playPosition: nil)).path
    return """
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
            <title>Swift Talk by objc.io</title>

        <style type="text/css">
            #outlook a{
                padding:0;
            }
            .ReadMsgBody{
                width:100%;
            }
            .ExternalClass{
                width:100%;
            }
            .ExternalClass,.ExternalClass p,.ExternalClass span,.ExternalClass font,.ExternalClass td,.ExternalClass div{
                line-height:100%;
            }
            body,table,td,p,a,li,blockquote{
                -webkit-text-size-adjust:100%;
                -ms-text-size-adjust:100%;
            }
            table,td{
                mso-table-lspace:0pt;
                mso-table-rspace:0pt;
            }
            img{
                -ms-interpolation-mode:bicubic;
            }
            body{
                margin:0;
                padding:0;
            }
            img{
                border:0;
                height:auto;
                line-height:100%;
                outline:none;
                text-decoration:none;
            }
            table{
                border-collapse:collapse !important;
            }
            body,#bodyTable,#bodyCell{
                height:100% !important;
                margin:0;
                padding:0;
                width:100% !important;
            }
            #bodyCell{
                padding:0px;
            }
            #templateContainer{
                width:600px;
            }
            body,#bodyTable{
                font-family:Helvetica;
            }
            #bodyCell{
                background-color:#FFFFFF;
            }
        /*
        @tab Page
        @section heading 1
        @style heading 1
        */
            h1{
                /*@editable*/color:#202020 !important;
                /*@editable*/display:block;
                /*@editable*/font-size:26px;
                /*@editable*/font-style:normal;
                /*@editable*/font-weight:bold;
                /*@editable*/line-height:100%;
                /*@editable*/letter-spacing:normal;
                /*@editable*/margin-top:30px;
                /*@editable*/margin-right:0;
                /*@editable*/margin-bottom:15px;
                /*@editable*/margin-left:0;
                /*@editable*/text-align:left;
            }
        /*
        @tab Page
        @section heading 2
        @style heading 2
        */
            h2{
                /*@editable*/color:#404040 !important;
                /*@editable*/display:block;
                /*@editable*/font-size:20px;
                /*@editable*/font-style:normal;
                /*@editable*/font-weight:bold;
                /*@editable*/line-height:100%;
                /*@editable*/letter-spacing:normal;
                /*@editable*/margin-top:30px;
                /*@editable*/margin-right:0;
                /*@editable*/margin-bottom:15px;
                /*@editable*/margin-left:0;
                /*@editable*/text-align:left;
            }
        /*
        @tab Page
        @section heading 1 sub
        @style heading 1 sub
        */
            h3{
                /*@tab Page
    @section heading 1 sub
    @style heading 1 sub*/color:#606060 !important;
                display:block;
                font-size:16px;
                font-style:italic;
                font-weight:normal;
                line-height:100%;
                letter-spacing:normal;
                margin-top:0;
                margin-right:0;
                margin-bottom:15px;
                margin-left:0;
                text-align:left;
            }
        /*
        @tab Page
        @section heading 2 sub
        @style heading 2 sub
        */
            h4{
                /*@tab Page
    @section heading 2 sub
    @style heading 2 sub*/color:#808080 !important;
                display:block;
                font-size:14px;
                font-style:italic;
                font-weight:normal;
                line-height:100%;
                letter-spacing:normal;
                margin-top:0;
                margin-right:0;
                margin-bottom:15px;
                margin-left:0;
                text-align:left;
            }
            p{
                margin-top:0;
                margin-bottom:10px;
            }
            .headerContent{
                color:#FFFFFF;
                font-size:30px;
                font-weight:normal;
                line-height:100%;
                padding-top:0;
                padding-right:0;
                padding-bottom:0;
                padding-left:0;
                text-align:left;
                vertical-align:middle;
            }
            .headerContent a:link,.headerContent a:visited,.headerContent a .yshortcuts {
                color:#FFFFFF;
                font-weight:normal;
                text-decoration:none;
            }
            #headerImage{
                height:auto;
                max-width:600px;
            }
            .bodyContent{
                color:#303030;
                font-size:14px;
                line-height:150%;
                padding-top:20px;
                padding-right:20px;
                padding-bottom:40px;
                padding-left:20px;
                text-align:left;
            }
            .bodyContent table{
                font-size:14px;
            }
            .bodyContent a:link,.bodyContent a:visited,.bodyContent a .yshortcuts {
                color:#1793D7;
                font-weight:normal;
                text-decoration:underline;
                word-break:break-word;
            }
            .bodyContent img{
                display:inline;
                height:auto;
                max-width:560px;
            }
            #templateFooterContainer{
                background-color:#F4F4F4;
                width:600px;
            }
            #templateFooter{
                max-width:600px;
            }
            .footerContent{
                color:#606060;
                font-size:11px;
                line-height:120%;
                padding-top:20px;
                padding-right:20px;
                padding-bottom:20px;
                padding-left:20px;
                text-align:left;
            }
            .footerContent a:link,.footerContent a:visited,.footerContent a .yshortcuts,.footerContent a span {
                color:#404040;
                font-weight:normal;
                text-decoration:underline;
            }
        @media only screen and (max-width: 480px){
            body,table,td,p,a,li,blockquote{
                -webkit-text-size-adjust:none !important;
            }

    }	@media only screen and (max-width: 480px){
            body{
                width:100% !important;
                min-width:100% !important;
            }

    }	@media only screen and (max-width: 480px){
            #bodyCell{
                padding:0px !important;
            }

    }	@media only screen and (max-width: 480px){
            #templateContainer{
                max-width:600px !important;
                width:100% !important;
            }

    }	@media only screen and (max-width: 480px){
            h1{
                font-size:36px !important;
                line-height:100% !important;
                margin-top:45px;
                margin-bottom:21px;
            }

    }	@media only screen and (max-width: 480px){
            h2{
                font-size:30px !important;
                line-height:100% !important;
                margin-top:45px;
                margin-bottom:21px;
            }

    }	@media only screen and (max-width: 480px){
            h3{
                font-size:27px !important;
                line-height:100% !important;
                margin-bottom:21px;
            }

    }	@media only screen and (max-width: 480px){
            h4{
                font-size:24px !important;
                line-height:100% !important;
                margin-bottom:21px;
            }

    }	@media only screen and (max-width: 480px){
            #templatePreheader{
                display:none !important;
            }

    }	@media only screen and (max-width: 480px){
            #headerImage{
                height:auto !important;
                max-width:600px !important;
                width:100% !important;
            }

    }	@media only screen and (max-width: 480px){
            .headerContent{
                font-size:30px !important;
                line-height:125% !important;
            }

    }	@media only screen and (max-width: 480px){
            .bodyContent{
                font-size:27px !important;
                line-height:150% !important;
                padding-top:30px;
                padding-bottom:60px;
            }

    }	@media only screen and (max-width: 480px){
            .bodyContent table{
                font-size:27px;
            }

    }	@media only screen and (max-width: 480px){
            .footerContent{
                font-size:20px !important;
                line-height:120% !important;
            }

    }	@media only screen and (max-width: 480px){
            #templateFooterContainer{
                width:100% !important;
            }

    }</style></head>
        <body leftmargin="0" marginwidth="0" topmargin="0" marginheight="0" offset="0" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;margin: 0;padding: 0;font-family: Helvetica;height: 100% !important;width: 100% !important;">
            <center>
                <table align="center" border="0" cellpadding="0" cellspacing="0" height="100%" width="100%" id="bodyTable" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;margin: 0;padding: 0;font-family: Helvetica;border-collapse: collapse !important;height: 100% !important;width: 100% !important;">
                    <tr>
                        <td align="center" valign="top" id="bodyCell" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;margin: 0;padding: 0px;background-color: #FFFFFF;height: 100% !important;width: 100% !important;">
                            <table border="0" cellpadding="0" cellspacing="0" id="templateContainer" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;width: 600px;border-collapse: collapse !important;">
                                <tr>
                                    <td align="center" valign="top" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;">
                                        <table border="0" cellpadding="0" cellspacing="0" width="100%" id="templateHeader" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;border-collapse: collapse !important;">
                                            <tr>
                                                <td align="center" valign="top" class="headerContent" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;color: #FFFFFF;font-size: 30px;font-weight: normal;line-height: 100%;padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;text-align: left;vertical-align: middle;">
                                                    <img src="https://www.objc.io/external-assets/swift-talk-header.png" style="max-width: 600px;-ms-interpolation-mode: bicubic;border: 0;height: auto;line-height: 100%;outline: none;text-decoration: none;">
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                                <tr>
                                    <td align="center" valign="top" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;">
                                        <table border="0" cellpadding="0" cellspacing="0" width="100%" id="templateBody" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;border-collapse: collapse !important;">
                                            <tr>
                                                <td valign="top" class="bodyContent" mc:edit="body" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;color: #303030;font-size: 14px;line-height: 150%;padding-top: 20px;padding-right: 20px;padding-bottom: 40px;padding-left: 20px;text-align: left;">



    <p style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;margin-top: 0;margin-bottom: 10px;">
    Dear Swift Talk Subscribers,
    <br><br>
    We just published episode \(episode.number):
    <a href="\(url)" target="_blank" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;color: #1793D7;font-weight: normal;text-decoration: underline;word-break: break-word;">\(episode.fullTitle)</a>
    <br><br>
    \(episode.synopsis)
    <br><br>

    <a href="\(url)" target="_blank" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;color: #1793D7;font-weight: normal;text-decoration: underline;word-break: break-word;"><img align="none" height="315" src="\(episode.posterURL(width: 1120, height: 630).absoluteString)" style="width: 560px;height: 315px;margin: 0px;-ms-interpolation-mode: bicubic;border: 0;line-height: 100%;outline: none;text-decoration: none;display: inline;max-width: 560px;" width="560"></a>

    <br><br>

    We hope you enjoy this new episode. Please send any questions and feedback our way!
    <br><br>
    Best from Berlin,<br>
    Chris &amp; Florian
    </p>


                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    <tr>
                        <td align="center" valign="top" id="templateFooterContainer" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;background-color: #F4F4F4;width: 600px;">
                            <table border="0" cellpadding="0" cellspacing="0" id="templateFooter" width="600" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;max-width: 600px;border-collapse: collapse !important;">
                                <tr>
                                    <td valign="top" class="footerContent" mc:edit="footer" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;color: #606060;font-size: 11px;line-height: 120%;padding-top: 20px;padding-right: 20px;padding-bottom: 20px;padding-left: 20px;text-align: left;">
                                        You are receiving this email because you opted in at our website <a href="https://talk.objc.io" target="_blank" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;color: #404040;font-weight: normal;text-decoration: underline;">talk.objc.io</a>.
                                        <br>
                                        <br>
                                        Swift Talk is a project by objc.io
                                        <br>
                                        <br>
                                        Contact us at <a href="mailto:mail@objc.io" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;color: #404040;font-weight: normal;text-decoration: underline;">mail@objc.io</a><a style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;color: #404040;font-weight: normal;text-decoration: underline;"></a> or <a href="https://twitter.com/objcio" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;color: #404040;font-weight: normal;text-decoration: underline;">@objcio</a><br>
                                        Our mailing address is: Kugler &amp; Eidhof GbR • Paulsenstraße 26 • 12163 Berlin • Germany
                                        <br>
                                        <br>
                                        <a href="*|UNSUB|*" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;color: #404040;font-weight: normal;text-decoration: underline;">Unsubscribe from this list</a>&nbsp;&nbsp;&nbsp;<a href="*|UPDATE_PROFILE|*" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;color: #404040;font-weight: normal;text-decoration: underline;">Update subscription preferences</a>&nbsp;
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                </table>
            </center>
        </body>
    </html>
    """
}
