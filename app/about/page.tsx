import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { CheckCircle, Globe, Users, Lightbulb } from "lucide-react"

export default function AboutPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      {/* En-tête */}
      <section className="text-center py-12">
        <h1 className="text-4xl font-bold mb-4">À Propos de Nous</h1>
        <p className="text-xl text-muted-foreground max-w-3xl mx-auto">
          Nous sommes une équipe passionnée de développeurs qui créent des expériences web exceptionnelles en utilisant
          les technologies les plus modernes.
        </p>
      </section>

      {/* Notre Mission */}
      <section className="py-12">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          <div>
            <h2 className="text-3xl font-bold mb-6">Notre Mission</h2>
            <p className="text-lg text-muted-foreground mb-6">
              Nous nous engageons à créer des applications web performantes, accessibles et élégantes qui répondent aux
              besoins de nos utilisateurs tout en respectant les meilleures pratiques du développement moderne.
            </p>
            <div className="space-y-4">
              <div className="flex items-center gap-3">
                <CheckCircle className="h-5 w-5 text-green-600" />
                <span>Code de qualité et maintenable</span>
              </div>
              <div className="flex items-center gap-3">
                <CheckCircle className="h-5 w-5 text-green-600" />
                <span>Performance et accessibilité</span>
              </div>
              <div className="flex items-center gap-3">
                <CheckCircle className="h-5 w-5 text-green-600" />
                <span>Expérience utilisateur exceptionnelle</span>
              </div>
            </div>
          </div>
          <div className="bg-gradient-to-br from-blue-50 to-purple-50 rounded-2xl p-8">
            <div className="grid grid-cols-2 gap-6">
              <div className="text-center">
                <div className="text-3xl font-bold text-blue-600 mb-2">50+</div>
                <div className="text-sm text-muted-foreground">Projets Réalisés</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-green-600 mb-2">100%</div>
                <div className="text-sm text-muted-foreground">Satisfaction Client</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-purple-600 mb-2">24/7</div>
                <div className="text-sm text-muted-foreground">Support</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-orange-600 mb-2">5+</div>
                <div className="text-sm text-muted-foreground">Années d'Expérience</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Nos Valeurs */}
      <section className="py-12">
        <h2 className="text-3xl font-bold text-center mb-12">Nos Valeurs</h2>
        <div className="grid md:grid-cols-3 gap-8">
          <Card>
            <CardHeader>
              <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mb-4">
                <Lightbulb className="h-6 w-6 text-blue-600" />
              </div>
              <CardTitle>Innovation</CardTitle>
              <CardDescription>
                Nous restons à la pointe des technologies pour offrir des solutions innovantes
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Nous explorons constamment de nouvelles technologies et méthodologies pour améliorer nos processus de
                développement et la qualité de nos produits.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mb-4">
                <Users className="h-6 w-6 text-green-600" />
              </div>
              <CardTitle>Collaboration</CardTitle>
              <CardDescription>Le travail d'équipe et la communication sont au cœur de notre approche</CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Nous croyons en la force du travail collaboratif, tant en interne qu'avec nos clients, pour créer des
                solutions qui dépassent les attentes.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mb-4">
                <Globe className="h-6 w-6 text-purple-600" />
              </div>
              <CardTitle>Impact</CardTitle>
              <CardDescription>
                Nous créons des solutions qui ont un impact positif sur les utilisateurs
              </CardDescription>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Chaque projet que nous réalisons vise à améliorer l'expérience des utilisateurs et à créer de la valeur
                pour nos clients et leur communauté.
              </p>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Technologies */}
      <section className="py-12">
        <h2 className="text-3xl font-bold text-center mb-8">Technologies que nous utilisons</h2>
        <div className="flex flex-wrap justify-center gap-3">
          <Badge variant="secondary" className="text-sm py-2 px-4">
            Next.js
          </Badge>
          <Badge variant="secondary" className="text-sm py-2 px-4">
            React
          </Badge>
          <Badge variant="secondary" className="text-sm py-2 px-4">
            TypeScript
          </Badge>
          <Badge variant="secondary" className="text-sm py-2 px-4">
            Tailwind CSS
          </Badge>
          <Badge variant="secondary" className="text-sm py-2 px-4">
            Node.js
          </Badge>
          <Badge variant="secondary" className="text-sm py-2 px-4">
            PostgreSQL
          </Badge>
          <Badge variant="secondary" className="text-sm py-2 px-4">
            Prisma
          </Badge>
          <Badge variant="secondary" className="text-sm py-2 px-4">
            Vercel
          </Badge>
          <Badge variant="secondary" className="text-sm py-2 px-4">
            Git
          </Badge>
          <Badge variant="secondary" className="text-sm py-2 px-4">
            Docker
          </Badge>
        </div>
      </section>
    </div>
  )
}
